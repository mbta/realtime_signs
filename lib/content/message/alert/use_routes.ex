defmodule Content.Message.Alert.UseRoutes do
  @moduledoc """
  Custom default message for Union Sq because it does not get shuttle service
  """

  defstruct []

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(_) do
      "Use routes 87, 91 or 109"
    end
  end
end
