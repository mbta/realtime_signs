defmodule Engine.Config.Headway do
  @enforce_keys [:group_id, :range_high, :range_low]
  defstruct @enforce_keys ++ [:non_platform_text_line1, :non_platform_text_line2]

  @type group_id :: String.t()

  @type t :: %__MODULE__{
          group_id: group_id(),
          range_high: integer(),
          range_low: integer(),
          non_platform_text_line1: String.t() | nil,
          non_platform_text_line2: String.t() | nil
        }

  @spec from_map(String.t(), any()) :: {:ok, t()} | :error
  def from_map(group_id, %{"range_high" => high, "range_low" => low} = config)
      when is_integer(high) and is_integer(low) do
    {:ok,
     %__MODULE__{
       group_id: group_id,
       range_high: high,
       range_low: low,
       non_platform_text_line1: Map.get(config, "non_platform_text_line1"),
       non_platform_text_line2: Map.get(config, "non_platform_text_line2")
     }}
  end

  def from_map(_, _), do: :error
end
