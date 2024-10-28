defmodule Engine.Config.Headways do
  require Logger
  alias Engine.Config.Headway

  @spec create_table(:ets.tab()) :: :ets.tab()
  def create_table(table_name) do
    :ets.new(table_name, [:set, :protected, :named_table, read_concurrency: true])
  end

  @spec update_table(:ets.tab(), [Headway.t()]) :: :ok
  def update_table(table_name, headways) do
    existing_headway_ids = :ets.select(table_name, [{{:"$1", :_}, [], [:"$1"]}])
    new_headway_ids = Enum.map(headways, & &1.headway_id)
    to_delete_ids = existing_headway_ids -- new_headway_ids

    if to_delete_ids != [] do
      :ets.select_delete(table_name, for(id <- to_delete_ids, do: {{id, :_}, [], [true]}))
    end

    true = :ets.insert(table_name, Enum.map(headways, &{&1.headway_id, &1}))
    :ok
  end

  @spec get_headway(:ets.tab(), Headway.headway_id()) :: Headway.t() | nil
  def get_headway(table_name, headway_id) do
    case :ets.lookup(table_name, headway_id) do
      [{^headway_id, headway}] -> headway
      _ -> nil
    end
  end

  @spec parse(map()) :: [Headway.t()]
  def parse(map) do
    for {group, periods} <- map,
        {period, %{"range_low" => low, "range_high" => high}} <- periods,
        time_period = parse_time_period(period) do
      %Headway{headway_id: {group, time_period}, range_high: high, range_low: low}
    end
  end

  @spec parse_time_period(String.t()) :: Headway.time_period() | nil
  defp parse_time_period("weekday"), do: :weekday
  defp parse_time_period("saturday"), do: :saturday
  defp parse_time_period("sunday"), do: :sunday
  defp parse_time_period(_), do: nil
end
