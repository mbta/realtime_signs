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
          new_cars?: boolean,
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
    # audio: "Attention passengers, the next", visual: ""
    @attention_passengers_the_next "896"
    # audio: "Attention passengers, the next", visual: "Shorter 4 car"
    @shorter_4_car "923"
    @train_to "919"
    @train "920"
    @is_now_approaching "910"
    # audio: "is now approaching", visual: "now approaching"
    @now_approaching "924"
    @with_all_new_red_line_cars "893"
    # audio: "It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge.", visual: "Please move to front of the train to board."
    @four_car_train_message "922"
    # "Please stand back from the platform edge."
    @stand_back_message "925"
    @comma "21012"
    @period "21014"

    def to_params(%Content.Audio.Approaching{} = audio) do
      prefix = if audio.four_cars?, do: [@shorter_4_car], else: [@attention_passengers_the_next]

      train =
        if branch = Content.Utilities.route_branch_letter(audio.route_id),
          do: [branch_var(branch), @train_to, destination_var(audio.destination)],
          else: [destination_var(audio.destination), @train]

      approaching = if audio.four_cars?, do: [@now_approaching], else: [@is_now_approaching]
      platform = if audio.platform, do: [platform_var(audio.platform)], else: []
      new_cars = if audio.new_cars?, do: [@comma, @with_all_new_red_line_cars], else: []
      followup = if audio.four_cars?, do: [@four_car_train_message], else: [@stand_back_message]

      crowding =
        if audio.crowding_description,
          do: [Content.Utilities.crowding_description_var(audio.crowding_description)],
          else: []

      (prefix ++
         train ++ approaching ++ platform ++ new_cars ++ [@period] ++ followup ++ crowding)
      |> Utilities.take_message(:audio_visual)
    end

    def to_tts(%Content.Audio.Approaching{} = audio) do
      prefix = if audio.four_cars?, do: "Shorter 4 car ", else: ""
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id, :visual)
      approaching = if audio.four_cars?, do: "now approaching", else: "is now approaching"
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)
      platform = platform_string(audio.platform)
      new_cars = new_cars_string(audio.new_cars?)

      followup =
        if audio.four_cars?,
          do: " Please move to front of the train to board.",
          else: " Please stand back from the platform edge."

      {tts_text(audio),
       PaEss.Utilities.paginate_text(
         "#{prefix}#{train} #{approaching}#{platform}#{new_cars}.#{followup}#{crowding}"
       )}
    end

    def to_logs(%Content.Audio.Approaching{}) do
      []
    end

    defp tts_text(%Content.Audio.Approaching{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)
      platform = platform_string(audio.platform)
      new_cars = new_cars_string(audio.new_cars?)

      followup =
        if audio.four_cars?,
          do: PaEss.Utilities.four_cars_text(),
          else: " Please stand back from the platform edge."

      "Attention passengers: The next #{train} is now approaching#{platform}#{new_cars}.#{followup}#{crowding}"
    end

    defp destination_var(:alewife), do: "892"
    defp destination_var(:ashmont), do: "895"
    defp destination_var(:braintree), do: "902"
    defp destination_var(:mattapan), do: "913"
    defp destination_var(:bowdoin), do: "900"
    defp destination_var(:wonderland), do: "921"
    defp destination_var(:oak_grove), do: "915"
    defp destination_var(:forest_hills), do: "907"
    defp destination_var(:lechmere), do: "912"
    defp destination_var(:north_station), do: "914"
    defp destination_var(:government_center), do: "908"
    defp destination_var(:park_street), do: "916"
    defp destination_var(:kenmore), do: "911"
    defp destination_var(:boston_college), do: "899"
    defp destination_var(:cleveland_circle), do: "904"
    defp destination_var(:reservoir), do: "917"
    defp destination_var(:riverside), do: "918"
    defp destination_var(:heath_street), do: "909"
    # Fall back to original takes
    defp destination_var(destination), do: PaEss.Utilities.destination_var(destination)

    defp platform_var(:ashmont), do: "894"
    defp platform_var(:braintree), do: "901"

    defp branch_var(:b), do: "897"
    defp branch_var(:c), do: "903"
    defp branch_var(:d), do: "905"
    defp branch_var(:e), do: "906"

    defp platform_string(:ashmont), do: " on the Ashmont platform"
    defp platform_string(:braintree), do: " on the Braintree platform"
    defp platform_string(_), do: ""

    defp new_cars_string(true), do: ", with all new Red Line cars"
    defp new_cars_string(false), do: ""
  end
end
