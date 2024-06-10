defprotocol Content.Message do
  @moduledoc """
  Place to define types or functions that apply to *all* the messages that
  the signs support.

  The interface to put text on a sign does not accept raw strings. It instead
  must be a Content.Message struct, which can be thought of something like
  a template. For example to make a sign say "Mattapan  BRD", you must use a
  %Content.Message.Predictions{headsign: "Mattapan", minutes: :boarding}
  struct.

  The `to_string` function returns either a plain string or a tuple with a
  list of strings if it's to be paginated on the sign, together with the length
  in seconds of how long each page should be displayed.
  """

  @type value :: String.t() | [{String.t(), non_neg_integer()}]
  @type pages :: [{top :: String.t(), bottom :: String.t(), duration :: integer()}]

  @doc "converts a content message to a string for display on a sign"
  @spec to_string(Content.Message.t()) :: value()
  def to_string(message)
end
