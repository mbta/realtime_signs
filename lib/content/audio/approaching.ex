defmodule Content.Audio.Approaching do
  @moduledoc """
  The next train to [destination] is now approaching
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination]
  defstruct @enforce_keys ++
              [
                :trip_id,
                :platform,
                :route_id,
                new_cars?: false,
                four_cars?: false,
                crowding_description: nil
              ]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil,
          route_id: String.t() | nil,
          new_cars?: boolean(),
          four_cars?: boolean(),
          crowding_description: {atom(), atom()} | nil
        }

  def new(%Predictions.Prediction{} = prediction, crowding_description, new_cars?) do
    [
      %__MODULE__{
        destination: Content.Utilities.destination_for_prediction(prediction),
        trip_id: prediction.trip_id,
        platform: Content.Utilities.stop_platform(prediction.stop_id),
        route_id: prediction.route_id,
        new_cars?: new_cars?,
        four_cars?: PaEss.Utilities.prediction_four_cars?(prediction),
        crowding_description: crowding_description
      }
    ]
  end

  defimpl Content.Audio do
    def to_params(%Content.Audio.Approaching{} = audio) do
      prefix = if audio.four_cars?, do: [:shorter_4_car], else: [:attention_passengers_the_next]
      train = PaEss.Utilities.train_description_tokens(audio.destination, audio.route_id, true)
      approaching = if audio.four_cars?, do: [:now_approaching], else: [:is_now_approaching]
      platform = if audio.platform, do: [platform_token(audio.platform)], else: []

      new_cars =
        if audio.new_cars? and not audio.four_cars?,
          do: [:",", :with_all_new_red_line_cars],
          else: []

      followup = if audio.four_cars?, do: [:four_car_train_message], else: [:stand_back_message]

      crowding =
        if audio.crowding_description, do: [{:crowding, audio.crowding_description}], else: []

      (prefix ++ train ++ approaching ++ platform ++ new_cars ++ [:.] ++ followup ++ crowding)
      |> Utilities.audio_message(:audio_visual)
    end

    def to_tts(%Content.Audio.Approaching{} = audio, max_text_length) do
      prefix = if audio.four_cars?, do: "Shorter 4 car ", else: ""
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id, :visual)
      approaching = if audio.four_cars?, do: "now approaching", else: "is now approaching"
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)
      platform = platform_string(audio.platform)
      new_cars = new_cars_string(audio.new_cars? and not audio.four_cars?)

      followup =
        if audio.four_cars?,
          do: " Please move to front of the train to board.",
          else: " Please stand back from the platform edge."

      {tts_text(audio),
       PaEss.Utilities.paginate_text(
         "#{prefix}#{train} #{approaching}#{platform}#{new_cars}.#{followup}#{crowding}",
         max_text_length
       )}
    end

    def to_logs(%Content.Audio.Approaching{}) do
      []
    end

    defp tts_text(%Content.Audio.Approaching{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)
      platform = platform_string(audio.platform)
      new_cars = new_cars_string(audio.new_cars? and not audio.four_cars?)

      followup =
        if audio.four_cars?,
          do: PaEss.Utilities.four_cars_text(),
          else: " Please stand back from the platform edge."

      "Attention passengers: The next #{train} is now approaching#{platform}#{new_cars}.#{followup}#{crowding}"
    end

    defp platform_token(:ashmont), do: :on_the_ashmont_platform
    defp platform_token(:braintree), do: :on_the_braintree_platform

    defp platform_string(:ashmont), do: " on the Ashmont platform"
    defp platform_string(:braintree), do: " on the Braintree platform"
    defp platform_string(_), do: ""

    defp new_cars_string(true), do: ", with all new Red Line cars"
    defp new_cars_string(false), do: ""
  end
end
