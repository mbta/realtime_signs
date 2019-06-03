defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  @bus_routes ["741", "742", "743"]

  @type transit_mode :: :train | :none

  @enforce_keys [:mode]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          mode: transit_mode()
        }

  @spec transit_mode_for_routes([String.t()]) :: transit_mode()
  def transit_mode_for_routes(routes) do
    if Enum.all?(routes, fn route -> route in @bus_routes end) do
      :none
    else
      :train
    end
  end

  defimpl Content.Message do
    def to_string(msg) do
      case msg.mode do
        :train -> "No train service"
        :none -> "No service"
      end
    end
  end
end
