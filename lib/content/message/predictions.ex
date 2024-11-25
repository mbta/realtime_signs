defmodule Content.Message.Predictions do
  @moduledoc """
  A message related to real time predictions. For example:

  Mattapan    BRD
  Mattapan    ARR
  Mattapan  2 min

  The constructor should be used rather than creating a struct
  yourself.
  """

  require Content.Utilities

  @enforce_keys [:destination, :minutes, :approximate?, :prediction, :special_sign, :terminal?]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          minutes: integer() | :boarding | :arriving | :approaching,
          approximate?: boolean(),
          prediction: Predictions.Prediction.t(),
          special_sign: :jfk_mezzanine | :bowdoin_eastbound | nil,
          terminal?: boolean()
        }

  @spec new(Predictions.Prediction.t(), boolean(), :jfk_mezzanine | :bowdoin_eastbound | nil) ::
          t()
  def new(%Predictions.Prediction{} = prediction, terminal?, special_sign) do
    sec =
      if terminal? do
        prediction.seconds_until_departure
      else
        prediction.seconds_until_arrival || prediction.seconds_until_departure
      end

    min = round(sec / 60)
    reverse_prediction? = Signs.Utilities.Predictions.reverse_prediction?(prediction, terminal?)

    {minutes, approximate?} =
      cond do
        prediction.stopped_at_predicted_stop? and (!terminal? or sec <= 30) -> {:boarding, false}
        !terminal? and sec <= 30 -> {:arriving, false}
        !terminal? and sec <= 60 -> {:approaching, false}
        min > 60 -> {60, true}
        reverse_prediction? and min > 20 -> {div(min, 10) * 10, true}
        true -> {max(min, 1), false}
      end

    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      minutes: minutes,
      approximate?: approximate?,
      prediction: prediction,
      special_sign: special_sign,
      terminal?: terminal?
    }
  end

  defimpl Content.Message do
    @width 18

    def to_string(%Content.Message.Predictions{
          destination: destination,
          minutes: minutes,
          approximate?: approximate?,
          prediction: %{stop_id: stop_id},
          special_sign: special_sign
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      duration_string =
        case minutes do
          :boarding -> "BRD"
          :arriving -> "ARR"
          :approaching -> "1 min"
          n -> "#{n}#{if approximate?, do: "+", else: ""} min"
        end

      track_number = Content.Utilities.stop_track_number(stop_id)

      cond do
        special_sign == :jfk_mezzanine and destination == :alewife ->
          platform_name = Content.Utilities.stop_platform_name(stop_id)

          {headsign_message, platform_message} =
            if is_integer(minutes) and minutes > 5 do
              {headsign, " (Platform TBD)"}
            else
              {headsign <> " (#{String.slice(platform_name, 0..0)})", " (#{platform_name} plat)"}
            end

          [
            {Content.Utilities.width_padded_string(headsign_message, duration_string, @width), 6},
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
  end
end
