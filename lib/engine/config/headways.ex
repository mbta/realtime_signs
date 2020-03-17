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
    new_headway_ids = Enum.map(headways, & &1.group_id)
    to_delete_ids = existing_headway_ids -- new_headway_ids

    if to_delete_ids != [] do
      :ets.select_delete(table_name, for(id <- to_delete_ids, do: {{id, :_}, [], [true]}))
    end

    true = :ets.insert(table_name, Enum.map(headways, &{&1.group_id, &1}))
    :ok
  end

  @spec get_headway(:ets.tab(), Headway.group_id()) :: Headway.t() | nil
  def get_headway(table_name, group_id) do
    case :ets.lookup(table_name, group_id) do
      [{^group_id, headway}] -> headway
      _ -> nil
    end
  end

  @spec parse(map()) :: [Headway.t()]
  def parse(map) do
    Enum.flat_map(map, fn {group_id, group_conf} ->
      case Headway.from_map(group_id, group_conf) do
        {:ok, conf} ->
          [conf]

        :error ->
          Logger.error(
            "event=group_headways_parse_error group_id=#{inspect(group_id)} group_conf=#{
              inspect(group_conf)
            }"
          )

          []
      end
    end)
  end
end
