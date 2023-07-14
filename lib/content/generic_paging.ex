defmodule Content.Message.GenericPaging do
  @enforce_keys [:messages]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          messages: [Content.Message.t()]
        }

  defimpl Content.Message do
    def to_string(%Content.Message.GenericPaging{messages: messages}) do
      Enum.map(messages, fn message ->
        case Content.Message.to_string(message) do
          [_ | _] = pages ->
            pages

          string ->
            {string, 6}
        end
      end)
      |> List.flatten()
    end
  end
end
