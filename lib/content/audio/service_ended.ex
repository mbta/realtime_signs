defmodule Content.Audio.ServiceEnded do
  alias PaEss.Utilities
  @enforce_keys [:location]
  defstruct @enforce_keys ++ [:destination, :line]

  @type location :: :platform | :station | :direction
  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          line: String.t() | nil,
          location: location()
        }

  defimpl Content.Audio do
    def to_tts(%Content.Audio.ServiceEnded{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.ServiceEnded{}) do
      []
    end

    defp tts_text(%Content.Audio.ServiceEnded{location: :station, line: line}) do
      line = if(line, do: "#{line} line", else: "Train")
      "#{line} service has ended for the night."
    end

    defp tts_text(%Content.Audio.ServiceEnded{location: :platform, destination: destination}) do
      destination_string = Utilities.destination_to_tts_string(destination)
      "This platform is closed. #{destination_string} service has ended for the night."
    end

    defp tts_text(%Content.Audio.ServiceEnded{location: :direction, destination: destination}) do
      destination_string = Utilities.destination_to_tts_string(destination)
      "#{destination_string} service has ended for the night."
    end
  end
end
