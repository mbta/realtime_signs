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
end
