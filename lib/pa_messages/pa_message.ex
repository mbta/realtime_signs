defmodule PaMessages.PaMessage do
  defstruct id: nil,
            visual_text: nil,
            audio_text: nil,
            audio_url: nil,
            priority: nil,
            sign_ids: [],
            interval_in_ms: nil

  @type t :: %__MODULE__{
          id: integer(),
          visual_text: String.t(),
          audio_text: String.t(),
          audio_url: String.t(),
          priority: integer(),
          sign_ids: [String.t()],
          interval_in_ms: non_neg_integer()
        }

  defimpl Content.Audio do
    def to_params(%PaMessages.PaMessage{audio_url: audio_url}) when not is_nil(audio_url) do
      nil
    end

    def to_params(%PaMessages.PaMessage{visual_text: visual_text}) do
      {:ad_hoc, {visual_text, :audio_visual}}
    end

    def to_tts(%PaMessages.PaMessage{visual_text: visual_text} = message, max_text_length) do
      audio =
        case message do
          %{audio_url: nil, audio_text: audio_text} -> audio_text
          %{audio_url: audio_url} -> {:url, audio_url}
        end

      {audio, PaEss.Utilities.paginate_text(visual_text, max_text_length)}
    end

    def to_logs(%PaMessages.PaMessage{id: id, priority: priority, interval_in_ms: interval_in_ms}) do
      [pa_message_id: id, pa_message_priority: priority, pa_message_interval: interval_in_ms]
    end
  end
end
