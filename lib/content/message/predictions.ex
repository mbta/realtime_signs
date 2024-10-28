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

  @terminal_brd_seconds 30
  @terminal_prediction_offset_seconds -60
  @reverse_prediction_certainty 360

  @enforce_keys [:destination, :minutes]
  defstruct [
    :destination,
    :minutes,
    :approximate?,
    :prediction,
    :station_code,
    :zone,
    terminal?: false
  ]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          minutes: integer() | :boarding | :arriving | :approaching,
          approximate?: boolean(),
          prediction: Predictions.Prediction.t(),
          station_code: String.t() | nil,
          zone: String.t() | nil,
          terminal?: boolean()
        }

  @spec non_terminal(Predictions.Prediction.t(), String.t(), String.t()) :: t()
  def non_terminal(prediction, station_code, zone) do
    # e.g., North Station which is non-terminal but has trips that begin there
    predicted_time = prediction.seconds_until_arrival || prediction.seconds_until_departure

    certainty =
      if prediction.seconds_until_arrival,
        do: prediction.arrival_certainty,
        else: prediction.departure_certainty

    {minutes, approximate?} =
      cond do
        prediction.stops_away == 0 -> {:boarding, false}
        predicted_time <= 30 -> {:arriving, false}
        predicted_time <= 60 -> {:approaching, false}
        true -> compute_minutes(predicted_time, certainty)
      end

    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      minutes: minutes,
      approximate?: approximate?,
      prediction: prediction,
      station_code: station_code,
      zone: zone
    }
  end

  @spec terminal(Predictions.Prediction.t(), String.t(), String.t()) :: t()
  def terminal(prediction, station_code, zone) do
    stopped_at? = prediction.stops_away == 0

    {minutes, approximate?} =
      case prediction.seconds_until_departure + @terminal_prediction_offset_seconds do
        x when x <= @terminal_brd_seconds and stopped_at? -> {:boarding, false}
        x when x <= @terminal_brd_seconds -> {1, false}
        x -> compute_minutes(x, prediction.departure_certainty)
      end

    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      minutes: minutes,
      approximate?: approximate?,
      prediction: prediction,
      station_code: station_code,
      zone: zone,
      terminal?: true
    }
  end

  defp compute_minutes(sec, certainty) do
    min = round(sec / 60)

    cond do
      min > 60 -> {60, true}
      certainty == @reverse_prediction_certainty && min > 20 -> {div(min, 10) * 10, true}
      true -> {min, false}
    end
  end

  defimpl Content.Message do
    require Logger

    @width 18
    @boarding "BRD"
    @arriving "ARR"

    def to_string(%{
          destination: destination,
          minutes: minutes,
          approximate?: approximate?,
          prediction: %{stop_id: stop_id},
          station_code: station_code,
          zone: zone
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      duration_string =
        case minutes do
          :boarding -> @boarding
          :arriving -> @arriving
          :approaching -> "1 min"
          n -> "#{n}#{if approximate?, do: "+", else: ""} min"
        end

      track_number = Content.Utilities.stop_track_number(stop_id)

      cond do
        station_code == "RJFK" and destination == :alewife and zone == "m" ->
          platform_name = Content.Utilities.stop_platform_name(stop_id)

          {headsign_message, platform_message} =
            if is_integer(minutes) and minutes > 5 do
              {headsign, " (Platform TBD)"}
            else
              {headsign <> " (#{String.slice(platform_name, 0..0)})", " (#{platform_name} plat)"}
            end

          [
            {Content.Utilities.width_padded_string(
               headsign_message,
               "#{duration_string}",
               @width
             ), 6},
            {headsign <> platform_message, 6}
          ]

        track_number ->
          [
            {Content.Utilities.width_padded_string(headsign, duration_string, @width), 6},
            {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", @width), 6}
          ]

        true ->
          Content.Utilities.width_padded_string(headsign, duration_string, @width)
      end
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end
  end
end
