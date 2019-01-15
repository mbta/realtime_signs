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

  @table __MODULE__

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec setting_expired?(map(), state) :: boolean
  defp setting_expired?(sign_config, state) do
    if Map.has_key?(sign_config, "expires") do
      case DateTime.from_iso8601(sign_config["expires"]) do
        {:ok, expiration_dt, 0} ->
          DateTime.compare(expiration_dt, state.time_fetcher.()) == :lt

        _ ->
          false
      end
    else
      false
    end
  end

  @spec enabled?(:ets.tab(), String.t()) :: boolean
  def enabled?(table_name \\ @table, sign_id) do
    case :ets.lookup(table_name, sign_id) do
      [{^sign_id, %{"enabled" => false}}] -> false
      _ -> true
    end
  end

  @spec custom_text(:ets.tab(), String.t()) :: {String.t(), String.t()} | nil
  def custom_text(table_name \\ @table, sign_id) do
    if Application.get_env(:realtime_signs, :static_text_enabled?) do
      case :ets.lookup(table_name, sign_id) do
        [{^sign_id, %{"line1" => line1, "line2" => line2}}] ->
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
          config = Enum.map(config, &transform_sign_config(state, &1))
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

  @spec transform_sign_config(state(), {String.t(), map()}) :: {String.t(), map()}
  defp transform_sign_config(state, {sign_id, sign_config}) do
    if setting_expired?(sign_config, state) do
      {sign_id, %{enabled: true}}
    else
      {sign_id, sign_config}
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
