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
          time_fetcher: (() -> DateTime.t())
        }

  @type sign_config :: :auto | :headway | :off | {:static_text, {String.t(), String.t()}}

  @table_signs :config_engine_signs
  @table_headways :config_engine_headways
  @table_chelsea_bridge :config_engine_chelsea_bridge

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec sign_config(:ets.tab(), String.t()) :: sign_config()
  def sign_config(table_name \\ @table_signs, sign_id) do
    case :ets.lookup(table_name, sign_id) do
      [{^sign_id, config}] -> config
      _ -> :auto
    end
  end

  @spec headway_config(:ets.tab(), String.t(), DateTime.t()) :: Headway.t() | nil
  def headway_config(table_name \\ @table_headways, headway_group, current_time) do
    time_period = Headway.current_time_period(current_time)
    Headways.get_headway(table_name, {headway_group, time_period})
  end

  @spec chelsea_bridge_config(:ets.tab()) :: :off | :auto
  def chelsea_bridge_config(table_name \\ @table_chelsea_bridge) do
    case :ets.lookup(table_name, :status) do
      [{_, "off"}] -> :off
      _ -> :auto
    end
  end

  def update(pid \\ __MODULE__) do
    schedule_update(pid, 0)
  end

  @spec init(map()) :: {:ok, state}
  def init(opts) do
    state = %{
      table_name_signs: @table_signs,
      table_name_headways: @table_headways,
      table_name_chelsea_bridge: @table_chelsea_bridge,
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

    :ets.new(state.table_name_chelsea_bridge, [
      :set,
      :protected,
      :named_table,
      read_concurrency: true
    ])
  end

  @spec handle_info(:update, state) :: {:noreply, state}
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

          config_chelsea_bridge = Map.get(config, "chelsea_bridge_announcements", "auto")

          :ets.insert(state.table_name_signs, Enum.into(config_signs, []))
          :ok = Headways.update_table(state.table_name_headways, config_headways)
          :ets.insert(state.table_name_chelsea_bridge, {:status, config_chelsea_bridge})

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
        Logger.warn("active_headend_ip: unable to fetch: #{inspect(e)}")
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

      true ->
        :auto
    end
  end

  defp schedule_update(pid, time \\ 1_000) do
    Process.send_after(pid, :update, time)
  end

  defp schedule_update_active_headend(pid, time \\ 10_000) do
    Process.send_after(pid, :update_active_headend, time)
  end
end
