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

  @type sign_config :: %{
          mode: :auto | :headway | :off | :static_text,
          enabled: boolean(),
          expires: DateTime.t() | nil,
          line1: String.t() | nil,
          line2: String.t() | nil
        }

  @table __MODULE__

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec setting_expired?(sign_config(), state) :: boolean
  defp setting_expired?(sign_config, state) do
    case sign_config[:expires] do
      nil ->
        false

      expires ->
        DateTime.compare(expires, state.time_fetcher.()) == :lt
    end
  end

  @spec enabled?(:ets.tab(), String.t()) :: boolean
  def enabled?(table_name \\ @table, sign_id) do
    case :ets.lookup(table_name, sign_id) do
      [{^sign_id, %{:enabled => false}}] -> false
      _ -> true
    end
  end

  @spec custom_text(:ets.tab(), String.t()) :: {String.t(), String.t()} | nil
  def custom_text(table_name \\ @table, sign_id) do
    if Application.get_env(:realtime_signs, :static_text_enabled?) do
      case :ets.lookup(table_name, sign_id) do
        [{^sign_id, %{:line1 => line1, :line2 => line2}}] when line1 != nil or line2 != nil ->
          {line1, line2}

        _ ->
          nil
      end
    else
      nil
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
      case updater.get(state[:current_version]) do
        {version, config} ->
          config =
            Enum.map(config, fn {sign_id, config_json} ->
              {sign_id, transform_sign_config(state, config_json)}
            end)

          :ets.insert(state.ets_table_name, Enum.into(config, []))
          version

        :unchanged ->
          state[:current_version]
      end

    {:noreply, Map.put(state, :current_version, latest_version)}
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec transform_sign_config(state(), map()) :: sign_config()
  defp transform_sign_config(state, config_json) do
    mode =
      case config_json["mode"] do
        "auto" ->
          :auto

        "headway" ->
          :headway

        "off" ->
          :off

        "static_text" ->
          :static_text

        _ ->
          :auto
      end

    expires =
      if config_json["expires"] != nil and config_json["expires"] != "" do
        case DateTime.from_iso8601(config_json["expires"]) do
          {:ok, expiration_dt, 0} -> expiration_dt
          _ -> nil
        end
      else
        nil
      end

    config = %{
      mode: mode,
      enabled: config_json["enabled"],
      expires: expires,
      line1: config_json["line1"],
      line2: config_json["line2"]
    }

    if setting_expired?(config, state) do
      %{
        mode: :auto,
        enabled: true,
        expires: nil,
        line1: nil,
        line2: nil
      }
    else
      config
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
      :ets.new(state[:ets_table_name], [:set, :protected, :named_table, read_concurrency: true])

    {:ok, state}
  end

  defp schedule_update(pid, time \\ 1_000) do
    Process.send_after(pid, :update, time)
  end
end
