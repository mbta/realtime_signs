defprotocol Content.Audio do
  @type audio_item :: String.t() | {:spanish, String.t()} | {:url, String.t()}
  @type tts_value :: {audio :: audio_item() | [audio_item()], visual :: String.t() | nil}

  @spec to_tts(Content.Audio.t()) :: tts_value()
  def to_tts(audio)
  @spec to_logs(Content.Audio.t()) :: keyword()
  def to_logs(audio)
end
