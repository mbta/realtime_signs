defmodule Signs.Utilities.EtsUtils do
  @doc """
  Updates an ETS table by resetting all existing keys to a default value
  and then merging new values into the table.
  Existing values will be overwritten with the empty_value in ETS.
  """
  def write_ets(table, values, empty_value) do
    :ets.tab2list(table)
    |> Enum.map(&{elem(&1, 0), empty_value})
    |> Map.new()
    |> Map.merge(values)
    |> Map.to_list()
    |> then(&:ets.insert(table, &1))
  end

  @doc "Writes new key-values to table and removes any existing keys from ETS that aren't in new_entries."
  def replace_contents(table, new_entry) when is_tuple(new_entry) do
    replace_contents(table, [new_entry])
  end

  def replace_contents(table, new_entries) do
    new_keys = MapSet.new(new_entries, &elem(&1, 0))

    current_table_keys =
      table
      |> :ets.tab2list()
      |> Enum.map(fn {key, _value} -> key end)
      |> MapSet.new()

    removed_keys = MapSet.difference(current_table_keys, new_keys)
    Enum.each(removed_keys, &:ets.delete(table, &1))

    :ets.insert(table, Enum.into(new_entries, []))
  end
end
