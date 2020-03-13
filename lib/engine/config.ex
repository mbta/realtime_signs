defmodule Engine.Config do
  @moduledoc """
  Manages the dynamic configurable pieces of the signs such as if they are on
  """

  use GenServer
  require Logger

  @type version_id :: String.t() | nil

  @type state :: %{
          ets_table_name: term(),
          current_version: version_id,
          time_fetcher: (() -> DateTime.t())
        }

  @type sign_config :: :auto | :headway | :off | {:static_text, {String.t(), String.t()}}

  @table __MODULE__

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec sign_config(:ets.tab(), String.t()) :: sign_config()
  def sign_config(table_name \\ @table, sign_id) do
    case :ets.lookup(table_name, sign_id) do
      [{^sign_id, config}] -> config
      _ -> :auto
    end
  end

  def update(pid \\ __MODULE__) do
    schedule_update(pid, 0)
  end

  @spec handle_info(:update, state) :: {:noreply, state}
  def handle_info(:update, state) do
    schedule_update(self())
    updater = Application.get_env(:realtime_signs, :external_config_getter)

    latest_version =
      case updater.get(state.current_version) do
        {version, config} ->
          # To handle two formats of signs config:
          # old: %{ "sign_id" => %{ sign config}, "sign_id2" => ...}
          # new: %{ "signs" => %{ "sign_id" => %{ sign_config }, ...}}
          config = Map.get(config, "signs", config)

          config =
            Enum.map(config, fn {sign_id, config_json} ->
              {sign_id, transform_sign_config(state, config_json)}
            end)

          :ets.insert(state.ets_table_name, Enum.into(config, []))
          version

        :unchanged ->
          state.current_version
      end

    {:noreply, Map.put(state, :current_version, latest_version)}
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

  @spec init(map()) :: {:ok, state}
  def init(opts) do
    state = %{
      ets_table_name: @table,
      current_version: nil,
      time_fetcher: opts[:time_fetcher] || fn -> DateTime.utc_now() end
    }

    schedule_update(self())

    @table =
      :ets.new(state.ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    {:ok, state}
  end

  defp schedule_update(pid, time \\ 1_000) do
    Process.send_after(pid, :update, time)
  end
end
