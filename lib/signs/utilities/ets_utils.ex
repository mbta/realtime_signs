defmodule Signs.Utilities.EtsUtils do
  @doc """
  Updates an ETS table by resetting all existing keys to a default value
  and then merging new values into the table.
  Existing values will be overwritten with the empty_value in ETS.
  """
  @spec write_ets(:ets.tab(), map(), any()) :: boolean()
  def write_ets(table, values, empty_value) when is_map(values) do
    :ets.tab2list(table)
    |> Enum.map(&{elem(&1, 0), empty_value})
    |> Map.new()
    |> Map.merge(values)
    |> Map.to_list()
    |> then(&:ets.insert(table, &1))
  end

  @spec write_ets(:ets.tab(), [{any(), any()}], any()) :: boolean()
  def write_ets(table, values_list, empty_value) when is_list(values_list) do
    write_ets(table, Map.new(values_list), empty_value)
  end

  @spec write_ets(:ets.tab(), {any(), any()}, any()) :: boolean()
  def write_ets(table, single_tuple, empty_value) when is_tuple(single_tuple) do
    write_ets(table, Map.new([single_tuple]), empty_value)
  end
end
