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

  @spec setting_expired?(String.t()) :: boolean
  defp setting_expired?(sign_id) do
    case :ets.lookup(@table, sign_id) do
      [{^sign_id, %{"expires" => expires}}] ->
        expires
        |> DateTime.from_iso8601()
        |> DateTime.compare(DateTime.utc_now()) == :lt

      _ ->
        false
    end
  end

  @spec enabled?(String.t()) :: boolean
  def enabled?(sign_id) do
    case :ets.lookup(@table, sign_id) do
      [{^sign_id, %{"enabled" => false}}] -> false
      _ -> true
    end
  end

  @spec custom_text(String.t()) :: {String.t(), String.t()} | nil
  def custom_text(sign_id) do
    case :ets.lookup(@table, sign_id) do
      [{^sign_id, %{"custom_line_1" => custom_line_1, "custom_line_2" => custom_line_2}}] ->
        if setting_expired?(sign_id) do
          nil
        else
          {custom_line_1, custom_line_2}
        end

      _ ->
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
          :ets.insert(@table, Enum.into(config, []))
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
