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

  @enforce_keys [:destination, :minutes]
  defstruct [
    :destination,
    :minutes,
    :route_id,
    :station_code,
    :stop_id,
    :trip_id,
    :zone,
    width: 18,
    new_cars?: false
  ]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          minutes: integer() | :boarding | :arriving | :approaching | :max_time,
          route_id: String.t(),
          stop_id: String.t(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          width: integer(),
          new_cars?: boolean(),
          station_code: String.t() | nil,
          zone: String.t() | nil
        }

  @spec non_terminal(Predictions.Prediction.t(), String.t(), String.t(), integer()) :: t() | nil
  def non_terminal(prediction, station_code, zone, width \\ 18)

  def non_terminal(prediction, station_code, zone, width) do
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

    case Content.Utilities.destination_for_prediction(
           prediction.route_id,
           prediction.direction_id,
           prediction.destination_stop_id
         ) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
          minutes: minutes,
          route_id: prediction.route_id,
          stop_id: prediction.stop_id,
          trip_id: prediction.trip_id,
          width: width,
          new_cars?: prediction.new_cars?,
          station_code: station_code,
          zone: zone
        }

      {:error, _} ->
        Logger.warn("no_destination_for_prediction #{inspect(prediction)}")
        nil
    end
  end

  @spec terminal(Predictions.Prediction.t(), integer()) :: t() | nil
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

    case Content.Utilities.destination_for_prediction(
           prediction.route_id,
           prediction.direction_id,
           prediction.destination_stop_id
         ) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
          minutes: minutes,
          route_id: prediction.route_id,
          stop_id: prediction.stop_id,
          trip_id: prediction.trip_id,
          width: width,
          new_cars?: prediction.new_cars?
        }

      {:error, _} ->
        Logger.warn("no_destination_for_prediction #{inspect(prediction)}")
        nil
    end
  end

  defimpl Content.Message do
    require Logger

    @boarding "BRD"
    @arriving "ARR"
    @max_time "20+ min"

    def to_string(%{
          destination: destination,
          minutes: minutes,
          width: width,
          stop_id: stop_id,
          station_code: station_code,
          zone: zone
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      duration_string =
        case minutes do
          :boarding -> @boarding
          :arriving -> @arriving
          :approaching -> "1 min"
          :max_time -> @max_time
          n -> "#{n} min"
        end

      track_number = Content.Utilities.stop_track_number(stop_id)

      cond do
        station_code == "RJFK" and destination == :alewife and zone == "m" ->
          platform_name = Content.Utilities.stop_platform_name(stop_id)

          {headsign_message, platform_message} =
            if minutes == :max_time,
              do: {headsign, " (Platform TBD)"},
              else:
                {headsign <> " (#{String.slice(platform_name, 0..0)})",
                 " (#{platform_name} plat)"}

          [
            {Content.Utilities.width_padded_string(
               headsign_message,
               "#{duration_string}",
               width
             ), 3},
            {headsign <> platform_message, 6}
          ]

        track_number ->
          [
            {Content.Utilities.width_padded_string(headsign, duration_string, width), 3},
            {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", width), 3}
          ]

        true ->
          Content.Utilities.width_padded_string(headsign, duration_string, width)
      end
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end
  end
end
