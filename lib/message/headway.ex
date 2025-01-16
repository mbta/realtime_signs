defmodule Message.Headway do
  @enforce_keys [:route, :destination, :range]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          range: {non_neg_integer(), non_neg_integer()},
          route: String.t() | nil
        }

  defimpl Message do
    def to_single_line(%Message.Headway{destination: destination, range: range, route: route}) do
      %Content.Message.Headways.Paging{destination: destination, range: range, route: route}
    end

    def to_full_page(%Message.Headway{destination: destination, range: range, route: route}) do
      {%Content.Message.Headways.Top{destination: destination, route: route},
       %Content.Message.Headways.Bottom{range: range}}
    end

    def to_multi_line(%Message.Headway{} = message), do: to_full_page(message)
  end
end
