defmodule Engine.ETS do
  @alias Engine.ETS

  # Safely replaces table contents.
  #
  # ETS doesn't support atomic bulk writes, so we can't just clear the whole table
  # (:ets.delete_all_objects/1) and then insert all of the new entries (:ets.insert/2),
  # because that would leave the table completely empty for a short period,
  # causing any concurrent reads during that time to fail.
  #
  # Instead, we remove only the table entries that are absent from new_entries.
  def replace_contents(table, new_entry) when is_tuple(new_entry) do
    replace_contents(table, [new_entry])
  end

  def replace_contents(table, new_entries) do
    new_keys = MapSet.new(new_entries, &elem(&1, 0))
    current_table_keys = keys(table)

    removed_keys = MapSet.difference(current_table_keys, new_keys)
    Enum.each(removed_keys, &:ets.delete(table, &1))

    :ets.insert(table, Enum.into(new_entries, []))
  end

  # Returns a MapSet of all keys in the table.
  defp keys(table) do
    keys(table, :ets.first(table), [])
  end

  defp keys(_table, :"$end_of_table", acc), do: MapSet.new(acc)

  defp keys(table, key, acc) do
    keys(table, :ets.next(table, key), [key | acc])
  end

end
