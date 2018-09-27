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

  @thirty_one_minutes 31 * 60

  @enforce_keys [:headsign, :minutes]
  defstruct [:headsign, :minutes, width: 18]

  @type t :: %__MODULE__{
          headsign: String.t(),
          minutes: integer() | :boarding | :arriving | :thirty_plus,
          width: integer()
        }

  @spec non_terminal(Predictions.Prediction.t(), integer(), boolean()) :: t()
  def non_terminal(prediction, width \\ 18, can_be_arriving?)

  def non_terminal(
        %Predictions.Prediction{stops_away: 0} = prediction,
        width,
        _can_be_arriving?
      ) do
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
      minutes: :boarding,
      width: width
    }
  end

  def non_terminal(prediction, width, can_be_arriving?) do
    minutes =
      cond do
        can_be_arriving? && prediction.seconds_until_arrival <= 30 -> :arriving
        prediction.seconds_until_arrival <= 30 -> 1
        prediction.seconds_until_arrival >= @thirty_one_minutes -> :thirty_plus
        true -> prediction.seconds_until_arrival |> Kernel./(60) |> round()
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
      width: width
    }
  end

  @spec terminal(Predictions.Prediction.t(), integer()) :: t()
  def terminal(prediction, width \\ 18)

  def terminal(prediction, width) do
    stopped_at? = prediction.stops_away == 0

    minutes =
      case prediction.seconds_until_departure do
        x when x <= 30 and stopped_at? -> :boarding
        x when x <= 30 -> 1
        x when x >= @thirty_one_minutes -> :thirty_plus
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
      width: width
    }
  end

  defimpl Content.Message do
    require Logger

    @boarding "BRD"
    @arriving "ARR"
    @thirty_plus "30+ min"

    def to_string(%{headsign: headsign, minutes: :boarding, width: width}) do
      Content.Utilities.width_padded_string(headsign, @boarding, width)
    end

    def to_string(%{headsign: headsign, minutes: :arriving, width: width}) do
      Content.Utilities.width_padded_string(headsign, @arriving, width)
    end

    def to_string(%{headsign: headsign, minutes: :thirty_plus, width: width}) do
      Content.Utilities.width_padded_string(headsign, @thirty_plus, width)
    end

    def to_string(%{headsign: headsign, minutes: n, width: width}) when n > 0 and n < 1000 do
      Content.Utilities.width_padded_string(headsign, "#{n} min", width)
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end
  end
end
