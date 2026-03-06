defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger
  alias Content.Audio

  @enforce_keys [:destination, :route_id, :track_number]
  defstruct @enforce_keys ++ [:trip_id, :four_cars_boarding?]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          route_id: String.t(),
          track_number: Content.Utilities.track_number(),
          four_cars_boarding?: boolean()
        }

  def new(%Predictions.Prediction{} = prediction, special_sign) do
    if Audio.TrackChange.park_track_change?(prediction) do
      [
        %Audio.TrackChange{
          destination: Content.Utilities.destination_for_prediction(prediction),
          route_id: prediction.route_id,
          berth: prediction.stop_id
        }
      ]
    else
      [
        %__MODULE__{
          destination: Content.Utilities.destination_for_prediction(prediction),
          trip_id: prediction.trip_id,
          route_id: prediction.route_id,
          track_number: Content.Utilities.stop_track_number(prediction.stop_id),
          four_cars_boarding?:
            PaEss.Utilities.prediction_four_cars?(prediction) &&
              PaEss.Utilities.prediction_alewife_braintree?(prediction)
        }
      ] ++
        if special_sign == :bowdoin_eastbound do
          [%Audio.BoardingButton{}]
        else
          []
        end
    end
  end

  defimpl Content.Audio do
    def to_params(audio) do
      track =
        case audio.track_number do
          1 -> [:on_track_1]
          2 -> [:on_track_2]
          nil -> []
        end

      four_cars_boarding =
        if audio.four_cars_boarding?,
          do: [:four_car_train_boarding_message],
          else: []

      PaEss.Utilities.audio_message(
        [:the_next] ++
          PaEss.Utilities.train_description_tokens(audio.destination, audio.route_id) ++
          [:is_now_boarding] ++ track ++ four_cars_boarding
      )
    end

    def to_tts(%Content.Audio.TrainIsBoarding{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.TrainIsBoarding{}) do
      []
    end

    defp tts_text(%Content.Audio.TrainIsBoarding{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)
      track = if(audio.track_number, do: " on track #{audio.track_number}", else: ".")

      four_cars_boarding =
        if audio.four_cars_boarding?,
          do: PaEss.Utilities.four_cars_boarding_text(),
          else: ""

      "The next #{train} is now boarding#{track}#{four_cars_boarding}"
    end
  end
end
