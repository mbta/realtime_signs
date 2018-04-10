defprotocol Content.Message do
  @moduledoc """
  Place to define types or functions that apply to *all* the messages that
  the signs support.

  The interface to put text on a sign does not accept raw strings. It instead
  must be a Content.Message struct, which can be thought of something like
  a template. For example to make a sign say "Mattapan  BRD", you must use a
  %Content.Message.Predictions{headsign: "Mattapan", minutes: :boarding}
  struct.
  """

  @doc "converts a content message to a string for display on a sign"
  def to_string(message)
end
