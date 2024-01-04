defmodule Content.Message.Alert.UseRoutes do
  @moduledoc """
  Custom default message for Union Sq because it does not get shuttle service
  """

  defstruct []

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(_) do
      "Use Routes 86, 87, or 91"
    end
  end
end
