defmodule PaMessages.PaMessage do
  defstruct id: nil,
            visual_text: nil,
            audio_text: nil,
            priority: nil,
            sign_ids: [],
            interval_in_ms: nil

  @type t :: %__MODULE__{
          id: integer(),
          visual_text: String.t(),
          audio_text: String.t(),
          priority: integer(),
          sign_ids: [String.t()],
          interval_in_ms: non_neg_integer()
        }

  defimpl Content.Audio do
    def to_params(%PaMessages.PaMessage{visual_text: visual_text}) do
      {:ad_hoc, {visual_text, :audio_visual}}
    end

    def to_tts(%PaMessages.PaMessage{visual_text: visual_text, audio_text: audio_text}) do
      {audio_text, PaEss.Utilities.paginate_text(visual_text)}
    end

    def to_logs(%PaMessages.PaMessage{id: id, priority: priority, interval_in_ms: interval_in_ms}) do
      [pa_message_id: id, pa_message_priority: priority, pa_message_interval: interval_in_ms]
    end
  end
end
