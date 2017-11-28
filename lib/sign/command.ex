defprotocol Sign.Command do
  @doc "Turns a PA/ESS message into a command string for POSTing"
  def to_command(payload)
end
