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
  @type priority :: integer()
  @type canned_message :: {:canned, {message_id(), message_vars(), av_type(), priority()}}
  @type ad_hoc_message :: {:ad_hoc, {String.t(), av_type(), priority()}}

  @type language :: :english | :spanish

  @doc "Converts an audio struct to the mid/vars params for the PA system"
  @spec to_params(Content.Audio.t()) :: canned_message() | ad_hoc_message() | nil
  def to_params(audio)
end
