defmodule Content.Message.Predictions do
  @moduledoc """
  A message related to real time predictions. For example:

  Mattapan    BRD
  Mattapan    ARR
  Mattapan  2 min

  The constructor should be used rather than creating a struct
  yourself.
  """

  require Logger
  require Content.Utilities

  @max_time Content.Utilities.max_time_seconds()
  @terminal_brd_seconds 30
  @terminal_prediction_offset_seconds -60

  @enforce_keys [:headsign, :minutes]
  defstruct [:headsign, :minutes, :route_id, :stop_id, :trip_id, width: 18]

  @type t :: %__MODULE__{
          headsign: String.t(),
          minutes: integer() | :boarding | :arriving | :approaching | :max_time,
          route_id: String.t(),
          stop_id: String.t(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          width: integer()
        }

  @spec non_terminal(Predictions.Prediction.t(), integer()) :: t()
  def non_terminal(prediction, width \\ 18)

  def non_terminal(prediction, width) do
    # e.g., North Station which is non-terminal but has trips that begin there
    predicted_time = prediction.seconds_until_arrival || prediction.seconds_until_departure

    minutes =
      cond do
        prediction.stops_away == 0 -> :boarding
        predicted_time <= 30 -> :arriving
        predicted_time <= 60 -> :approaching
        predicted_time >= @max_time -> :max_time
        true -> predicted_time |> Kernel./(60) |> round()
      end

    headsign =
      case Content.Utilities.headsign_for_prediction(
             prediction.route_id,
             prediction.direction_id,
             prediction.destination_stop_id
           ) do
        {:ok, dest} ->
          dest

        {:error, _} ->
          Logger.warn("Could not find headsign for prediction #{inspect(prediction)}")
          ""
      end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
      route_id: prediction.route_id,
      stop_id: prediction.stop_id,
      trip_id: prediction.trip_id,
      width: width
    }
  end

  @spec terminal(Predictions.Prediction.t(), integer()) :: t()
  def terminal(prediction, width \\ 18)

  def terminal(prediction, width) do
    stopped_at? = prediction.stops_away == 0

    minutes =
      case prediction.seconds_until_departure + @terminal_prediction_offset_seconds do
        x when x <= @terminal_brd_seconds and stopped_at? -> :boarding
        x when x <= @terminal_brd_seconds -> 1
        x when x >= @max_time -> :max_time
        x -> x |> Kernel./(60) |> round()
      end

    headsign =
      case Content.Utilities.headsign_for_prediction(
             prediction.route_id,
             prediction.direction_id,
             prediction.destination_stop_id
           ) do
        {:ok, dest} ->
          dest

        {:error, _} ->
          Logger.warn("Could not find headsign for prediction #{inspect(prediction)}")
          ""
      end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
      route_id: prediction.route_id,
      stop_id: prediction.stop_id,
      trip_id: prediction.trip_id,
      width: width
    }
  end

  defimpl Content.Message do
    require Logger

    @boarding "BRD"
    @arriving "ARR"
    @max_time "30+ min"

    def to_string(%{headsign: headsign, minutes: minutes, width: width, stop_id: stop_id}) do
      duration_string =
        case minutes do
          :boarding -> @boarding
          :arriving -> @arriving
          :approaching -> "1 min"
          :max_time -> @max_time
          n -> "#{n} min"
        end

      track_number = Content.Utilities.stop_track_number(stop_id)

      if track_number do
        [
          {Content.Utilities.width_padded_string(headsign, duration_string, width), 3},
          {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", width), 3}
        ]
      else
        Content.Utilities.width_padded_string(headsign, duration_string, width)
      end
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end
  end
end
