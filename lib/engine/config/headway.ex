defmodule Engine.Config.Headway do
  @enforce_keys [:group_id, :range_high, :range_low]
  defstruct @enforce_keys

  @type group_id :: String.t()

  @type t :: %__MODULE__{
          group_id: group_id(),
          range_high: integer(),
          range_low: integer()
        }

  @spec from_map(String.t(), any()) :: {:ok, t()} | :error
  def from_map(group_id, %{"range_high" => high, "range_low" => low})
      when is_integer(high) and is_integer(low) do
    {:ok,
     %__MODULE__{
       group_id: group_id,
       range_high: high,
       range_low: low
     }}
  end

  def from_map(_, _), do: :error
end
