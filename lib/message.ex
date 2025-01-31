defprotocol Message do
  @doc "render a single line of content, may include line-level paging"
  @spec to_single_line(Message.t()) :: Content.Message.t()
  def to_single_line(message)

  @doc "render two lines of content, must not include line-level paging"
  @spec to_full_page(Message.t()) :: {Content.Message.t(), Content.Message.t()}
  def to_full_page(message)

  @doc "render two lines of content, may include line-level paging"
  @spec to_multi_line(Message.t()) :: {Content.Message.t(), Content.Message.t()}
  def to_multi_line(message)

  @doc "produce a list of audios"
  @spec to_audio(Message.t(), boolean()) :: [Content.Audio.t()]
  def to_audio(message, multiple?)
end
