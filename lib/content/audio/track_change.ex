defmodule Content.Audio.TrackChange do
  @moduledoc """
  Track change: The next [line] train to [destination] is now boarding on [track]
  """

  require Logger

  @enforce_keys [:destination, :berth, :route_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          berth: String.t()
        }

  @spec park_track_change?(Predictions.Prediction.t()) :: boolean()
  def park_track_change?(%{route_id: "Green-B", stop_id: "70197"}), do: true
  def park_track_change?(%{route_id: "Green-C", stop_id: "70196"}), do: true
  def park_track_change?(%{route_id: "Green-D", stop_id: "70199"}), do: true
  def park_track_change?(%{route_id: "Green-E", stop_id: "70198"}), do: true
  def park_track_change?(_prediction), do: false

  defimpl Content.Audio do
    def to_params(%{route_id: route_id, berth: berth, destination: destination}) do
      PaEss.Utilities.audio_message(
        [:track_change, {:boarding, route_id, berth, destination}],
        :audio_visual
      )
    end

    def to_tts(%Content.Audio.TrackChange{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)

      platform =
        case audio.berth do
          "70196" -> "B"
          "70197" -> "C"
          "70198" -> "D"
          "70199" -> "E"
        end

      text = "Track change: The next #{train} is now boarding on the #{platform} platform"
      {text, PaEss.Utilities.paginate_text(text)}
    end

    def to_logs(%Content.Audio.TrackChange{}) do
      []
    end
  end
end
