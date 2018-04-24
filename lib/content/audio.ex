defprotocol Content.Audio do
  @moduledoc """
  Types of audio messages are defined as structs with certain
  variables. The PA system HTTP POSTs take a "mid" (message ID)
  and list of variables. Any "canned" audio announcement we want
  to make should be represented as a struct, which implements
  this protocol, in order to obtain the mid and vars.
  """

  @doc "Converts an audio struct to the mid/vars params for the PA system"
  @spec to_params(Content.Audio.t) :: {mid, vars} when mid: String.t, vars: [String.t]
  def to_params(audio)
end
