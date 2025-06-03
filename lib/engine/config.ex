defmodule Engine.Config do
  @moduledoc """
  Manages the dynamic configurable pieces of the signs such as if they are on
  """
  use GenServer
  require Logger
  alias Engine.Config.Headway
  alias Engine.Config.Headways

  @type version_id :: String.t() | nil

  @type state :: %{
          table_name_signs: term(),
          table_name_headways: term(),
          table_name_chelsea_bridge: term(),
          current_version: version_id,
          time_fetcher: (-> DateTime.t())
        }

  @type sign_config ::
          :auto | :headway | :off | :temporary_terminal | {:static_text, {String.t(), String.t()}}

  @table_signs :config_engine_signs
  @table_headways :config_engine_headways
  @table_chelsea_bridge :config_engine_chelsea_bridge
  @table_scus_migrated :config_engine_scus_migrated

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @callback sign_config(id :: String.t(), default :: Engine.Config.sign_config()) ::
              Engine.Config.sign_config()
  def sign_config(table \\ @table_signs, sign_id, default) do
    case :ets.lookup(table, sign_id) do
      [{^sign_id, config}] when not is_nil(config) -> config
      _ -> default
    end
  end

  @callback headway_config(String.t(), DateTime.t()) :: Engine.Config.Headway.t() | nil
  def headway_config(table_name \\ @table_headways, headway_group, current_time) do
    time_period = Headway.current_time_period(current_time)
    Headways.get_headway(table_name, {headway_group, time_period})
  end

  @callback scu_migrated?(String.t()) :: boolean()
  def scu_migrated?(table_name \\ @table_scus_migrated, scu_id) do
    case :ets.lookup(table_name, scu_id) do
      [{^scu_id, value}] -> value
      _ -> false
    end
  end

  @callback chelsea_bridge_config() :: :off | :auto
  def chelsea_bridge_config(table_name \\ @table_chelsea_bridge) do
    case :ets.lookup(table_name, :status) do
      [{_, "auto"}] -> :auto
      _ -> :off
    end
  end

  def update(pid \\ __MODULE__) do
    schedule_update(pid, 0)
  end

  @impl true
  def init(opts) do
    state = %{
      table_name_signs: @table_signs,
      table_name_headways: @table_headways,
      table_name_chelsea_bridge: @table_chelsea_bridge,
      table_name_scus_migrated: @table_scus_migrated,
      current_version: nil,
      time_fetcher: opts[:time_fetcher] || fn -> DateTime.utc_now() end
    }

    schedule_update(self())
    send(self(), :update_active_headend)

    create_tables(state)

    {:ok, state}
  end

  def create_tables(state) do
    :ets.new(state.table_name_signs, [:set, :protected, :named_table, read_concurrency: true])
    Headways.create_table(state.table_name_headways)
    :ets.new(state.table_name_scus_migrated, [:named_table, read_concurrency: true])

    :ets.new(state.table_name_chelsea_bridge, [
      :set,
      :protected,
      :named_table,
      read_concurrency: true
    ])
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())
    updater = Application.get_env(:realtime_signs, :external_config_getter)

    latest_version =
      case updater.get(state.current_version) do
        {version, config} ->
          config_signs =
            Map.get(config, "signs", %{})
            |> Enum.map(fn {sign_id, config_json} ->
              {sign_id, transform_sign_config(state, config_json)}
            end)

          config_headways =
            config
            |> Map.get("configured_headways", %{})
            |> Headways.parse()

          scus_migrated = Map.get(config, "scus_migrated", %{})
          config_chelsea_bridge = Map.get(config, "chelsea_bridge_announcements", "auto")

          :ets.insert(state.table_name_signs, Enum.into(config_signs, []))
          :ok = Headways.update_table(state.table_name_headways, config_headways)
          :ets.insert(state.table_name_chelsea_bridge, {:status, config_chelsea_bridge})
          :ets.insert(state.table_name_scus_migrated, Map.to_list(scus_migrated))

          version

        :unchanged ->
          state.current_version
      end

    {:noreply, Map.put(state, :current_version, latest_version)}
  end

  def handle_info(:update_active_headend, state) do
    schedule_update_active_headend(self())
    updater = Application.get_env(:realtime_signs, :external_config_getter)

    case updater.get_active_headend_ip() do
      {:ok, active_headend_ip} ->
        Application.put_env(:realtime_signs, :sign_head_end_host, active_headend_ip)
        Logger.info("active_headend_ip: current: #{active_headend_ip}")

      {:error, e} ->
        Logger.warning("active_headend_ip: unable to fetch: #{inspect(e)}")
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec transform_sign_config(state(), map()) :: sign_config()
  defp transform_sign_config(state, config_json) do
    expires =
      if config_json["expires"] != nil and config_json["expires"] != "" do
        case DateTime.from_iso8601(config_json["expires"]) do
          {:ok, expiration_dt, 0} -> expiration_dt
          _ -> nil
        end
      else
        nil
      end

    expired =
      if expires != nil do
        DateTime.compare(expires, state.time_fetcher.()) == :lt
      else
        false
      end

    if expired do
      :auto
    else
      parse_sign_config(config_json)
    end
  end

  @spec parse_sign_config(map()) :: sign_config()
  defp parse_sign_config(config_json) do
    cond do
      config_json["mode"] == "off" ->
        :off

      config_json["mode"] == "static_text" or config_json["line1"] != nil or
          config_json["line2"] != nil ->
        {:static_text, {config_json["line1"], config_json["line2"]}}

      config_json["mode"] == "auto" ->
        :auto

      config_json["mode"] == "headway" ->
        :headway

      config_json["mode"] == "temporary_terminal" ->
        :temporary_terminal

      true ->
        nil
    end
  end

  defp schedule_update(pid, time \\ 1_000) do
    Process.send_after(pid, :update, time)
  end

  defp schedule_update_active_headend(pid, time \\ 10_000) do
    Process.send_after(pid, :update_active_headend, time)
  end
end
