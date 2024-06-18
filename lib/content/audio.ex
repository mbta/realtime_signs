defprotocol Content.Audio do
  @moduledoc """
  Types of audio messages are defined as structs with certain
  variables. The PA system HTTP POSTs take a "mid" (message ID)
  and list of variables. Any "canned" audio announcement we want
  to make should be represented as a struct, which implements
  this protocol, in order to obtain the mid and vars.
  """

  @type av_type :: :audio | :visual | :audio_visual
  @type message_id :: String.t()
  @type message_vars :: [String.t()]
  @type canned_message :: {:canned, {message_id(), message_vars(), av_type()}}
  @type ad_hoc_message :: {:ad_hoc, {String.t(), av_type()}}

  @type language :: :english | :spanish
  @type value :: canned_message() | ad_hoc_message() | nil
  @type tts_value :: {audio :: String.t(), visual :: Content.Message.pages() | nil}

  @doc "Converts an audio struct to the mid/vars params for the PA system"
  @spec to_params(Content.Audio.t()) :: value()
  def to_params(audio)
  @spec to_tts(Content.Audio.t()) :: tts_value()
  def to_tts(audio)
end
