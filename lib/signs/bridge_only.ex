defmodule Signs.BridgeOnly do
  @moduledoc """
  This type of sign simply checks the Bridge Engine every 5 minutes and sends
  a canned A/V message if the bridge is up.

  Since this sign will typically co-exist on a sign powered by other software,
  it does not send any static text or do any other messagin of its own.
  """

  use GenServer
  require Logger

  @enforce_keys [
    :id,
    :pa_ess_id,
    :bridge_engine,
    :bridge_id,
    :sign_updater,
    :bridge_check_period_ms,
  ]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
    id: String.t(),
    pa_ess_id: PaEss.id(),
    bridge_engine: module(),
    bridge_id: String.t(),
    sign_updater: module(),
    bridge_check_period_ms: integer(),
  }

  def start_link(%{"type" => "bridge_only"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    bridge_engine = opts[:bridge_engine] || Engine.Bridge

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      pa_ess_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "pa_ess_zone")},
      bridge_engine: bridge_engine,
      bridge_id: Map.fetch!(config, "bridge_id"),
      sign_updater: sign_updater,
      bridge_check_period_ms: 5 * 60 * 1_000,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  @spec init(t()) :: {:ok, t()}
  def init(sign) do
    schedule_bridge_check(self(), sign.bridge_check_period_ms)
    {:ok, sign}
  end

  def handle_info(:bridge_check, sign) do
    schedule_bridge_check(self(), sign.bridge_check_period_ms)

    try do
      case sign.bridge_engine.status(sign.bridge_id) do
        {"Raised", duration} ->
          {english, spanish} = Content.Audio.BridgeIsUp.create_bridge_messages(duration)
          for audio <- [english, spanish] do
            if audio, do: sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 120, System.system_time(:second))
          end
        e ->
          Logger.warn("Error in bridge_only.update_content: #{inspect e}")
          nil
      end
      {:noreply, sign}
    rescue
      _ -> {:noreply, sign}
    end
  end
  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} #{inspect(state.id)} unknown message: #{inspect msg}")
    {:noreply, state}
  end

  defp schedule_bridge_check(pid, ms) do
    Process.send_after(pid, :bridge_check, ms)
  end
end
