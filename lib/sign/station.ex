defmodule Sign.Station do
  defstruct [
    :stop_id,
    :zones,
    :display_type,
    :enabled?
  ]

  @type t :: %__MODULE__{
    stop_id: String.t,
    zones: %{required(0 | 1) => atom},
    display_type: :separate | :combined | {:one_line, 0 | 1},
    enabled?: boolean
  }
end
