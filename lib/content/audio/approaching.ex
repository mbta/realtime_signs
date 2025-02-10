defmodule Content.Audio.Approaching do
  @moduledoc """
  The next train to [destination] is now approaching
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination]
  defstruct @enforce_keys ++
              [:trip_id, :platform, :route_id, new_cars?: false, crowding_description: nil]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil,
          route_id: String.t() | nil,
          new_cars?: boolean,
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
        crowding_description: crowding_description
      }
    ]
  end

  defimpl Content.Audio do
    @attention_passengers "783"
    @now_approaching_new_rl_cars "786"

    def to_params(%Content.Audio.Approaching{route_id: route_id} = audio)
        when route_id in ["Mattapan", "Green-B", "Green-C", "Green-D", "Green-E"] do
      handle_unknown_destination(audio)
    end

    def to_params(%Content.Audio.Approaching{} = audio) do
      message =
        if audio.new_cars? do
          [
            @attention_passengers,
            PaEss.Utilities.destination_var(audio.destination),
            @now_approaching_new_rl_cars
          ]
        else
          [destination_var(audio.destination, audio.platform, audio.route_id)]
        end

      crowding =
        if audio.crowding_description do
          [Content.Utilities.crowding_description_var(audio.crowding_description)]
        else
          []
        end

      Utilities.take_message(message ++ crowding, :audio_visual)
    end

    def to_tts(%Content.Audio.Approaching{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id, :visual)
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)

      new_cars =
        if(audio.new_cars? && audio.route_id == "Red", do: "with all new Red Line cars", else: "")

      pages =
        [{train, "now approaching", 6}] ++
          PaEss.Utilities.paginate_text(new_cars) ++ PaEss.Utilities.paginate_text(crowding)

      {tts_text(audio), pages}
    end

    def to_logs(%Content.Audio.Approaching{}) do
      []
    end

    defp tts_text(%Content.Audio.Approaching{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)

      new_cars =
        if audio.new_cars? && audio.route_id == "Red" do
          ", with all new Red Line cars."
        else
          "."
        end

      "Attention passengers: The next #{train} is now approaching#{new_cars}#{crowding}"
    end

    @spec handle_unknown_destination(Content.Audio.Approaching.t()) :: nil
    defp handle_unknown_destination(audio) do
      Logger.info(
        "unknown_approaching_audio: destination=#{audio.destination} route_id=#{audio.route_id} platform=#{audio.platform}"
      )

      nil
    end

    @spec destination_var(PaEss.destination(), Content.platform(), String.t()) :: String.t() | nil
    defp destination_var(:alewife, :ashmont, _route_id), do: "32125"
    defp destination_var(:alewife, :braintree, _route_id), do: "32126"
    defp destination_var(:alewife, nil, _route_id), do: "32124"
    defp destination_var(:ashmont, nil, "Red"), do: "32127"
    defp destination_var(:braintree, nil, _route_id), do: "32128"
    defp destination_var(:bowdoin, nil, _route_id), do: "32121"
    defp destination_var(:wonderland, nil, _route_id), do: "32120"
    defp destination_var(:forest_hills, nil, _route_id), do: "32123"
    defp destination_var(:oak_grove, nil, _route_id), do: "32122"
  end
end
