defmodule Message.OvernightPeriod do
  @enforce_keys [:route]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          route: String.t() | nil
        }

  defimpl Message do
    def to_single_line(%Message.OvernightPeriod{}, _) do
      ""
    end

    def to_full_page(%Message.OvernightPeriod{}) do
      {"", ""}
    end

    def to_multi_line(%Message.OvernightPeriod{} = message), do: to_full_page(message)

    def to_audio(%Message.OvernightPeriod{}, _multiple?) do
      []
    end
  end
end
