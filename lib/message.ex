defprotocol Message do
  @doc "render a single line of content"
  @spec to_single_line(Message.t(), :long | :short) :: Content.Message.value() | nil
  def to_single_line(message, variant)

  @doc "render two lines of content"
  @spec to_full_page(Message.t()) :: {Content.Message.value(), Content.Message.value()}
  def to_full_page(message)

  @doc "produce a list of audios"
  @spec to_audio(Message.t(), boolean()) :: [Content.Audio.t()]
  def to_audio(message, multiple?)
end
