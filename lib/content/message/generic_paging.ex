defmodule Content.Message.GenericPaging do
  @moduledoc """
  Can be used to page between multiple full-page messages e.g. headways and early AM timestamp
  """
  @enforce_keys [:messages]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          messages: [Content.Message.t()]
        }

  defimpl Content.Message do
    def to_string(%Content.Message.GenericPaging{messages: messages}) do
      Enum.map(messages, fn message ->
        {Content.Message.to_string(message), 6}
      end)
    end
  end
end
