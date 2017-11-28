defmodule Sign.Content do
  defstruct [
    station: nil,
    messages: []
  ]

  def new, do: %__MODULE__{}

  @doc """
  The number of usable characters on the PA signs.
  """
  def sign_width(), do: 18

  @doc """
  The station, specified via 4-letter ID.
  """
  def station(state, station), do: %{state | station: station}

  @doc """
  A list of messages from Sign.Message.
  """
  def messages(state, messages), do: %{state | messages: messages}

  def to_command(state) do
    [
      MsgType: "SignContent",
      sta: "#{state.station}"
    ]
    ++
    Enum.map(state.messages, fn (message) ->
      {:c, Sign.Message.to_string(message)}
    end)
  end

  defimpl Sign.Command do
    def to_command(state), do: Sign.Content.to_command(state)
  end
end
