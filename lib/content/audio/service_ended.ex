defmodule Content.Audio.ServiceEnded do
  alias PaEss.Utilities
  @enforce_keys [:location]
  defstruct @enforce_keys ++ [:destination, :route]

  @type location :: :platform | :station | :direction
  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil,
          location: location()
        }

  defimpl Content.Audio do
    def to_params(%Content.Audio.ServiceEnded{location: :station, route: route}) do
      Utilities.audio_message([{:line, route}, :service_ended])
    end

    def to_params(%Content.Audio.ServiceEnded{location: :platform, destination: destination}) do
      Utilities.audio_message([:platform_closed, destination, :service_ended])
    end

    def to_params(%Content.Audio.ServiceEnded{location: :direction, destination: destination}) do
      Utilities.audio_message([destination, :service_ended])
    end

    def to_tts(%Content.Audio.ServiceEnded{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.ServiceEnded{}) do
      []
    end

    defp tts_text(%Content.Audio.ServiceEnded{location: :station, route: route}) do
      line = if(route, do: "#{route} line", else: "Train")
      "#{line} service has ended for the night."
    end

    defp tts_text(%Content.Audio.ServiceEnded{location: :platform, destination: destination}) do
      destination_string = Utilities.destination_to_ad_hoc_string(destination)
      "This platform is closed. #{destination_string} service has ended for the night."
    end

    defp tts_text(%Content.Audio.ServiceEnded{location: :direction, destination: destination}) do
      destination_string = Utilities.destination_to_ad_hoc_string(destination)
      "#{destination_string} service has ended for the night."
    end
  end
end
