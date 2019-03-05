defmodule Signs.Realtime do
  @moduledoc """
  A two-line sign that displays realtime countdown information from one or more sources. See
  Signs.Utilities.SourceConfig for information on the JSON format.
  """

  use GenServer
  require Logger

  alias Signs.Utilities

  @enforce_keys [
    :id,
    :pa_ess_id,
    :source_config,
    :current_content_top,
    :current_content_bottom,
    :prediction_engine,
    :headway_engine,
    :alerts_engine,
    :sign_updater,
    :tick_top,
    :tick_bottom,
    :tick_read,
    :expiration_seconds,
    :read_period_seconds
  ]

  defstruct @enforce_keys ++ [announced_arrivals: MapSet.new()]

  @type line_content :: {Utilities.SourceConfig.source() | nil, Content.Message.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          pa_ess_id: PaEss.id(),
          source_config: Utilities.SourceConfig.config(),
          current_content_top: line_content(),
          current_content_bottom: line_content(),
          prediction_engine: module(),
          headway_engine: module(),
          alerts_engine: module(),
          sign_updater: module(),
          tick_bottom: non_neg_integer(),
          tick_top: non_neg_integer(),
          tick_read: non_neg_integer(),
          expiration_seconds: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          announced_arrivals: MapSet.t()
        }

  def start_link(%{"type" => "realtime"} = config, opts \\ []) do
    prediction_engine = opts[:prediction_engine] || Engine.Predictions
    headway_engine = opts[:headway_engine] || Engine.Headways
    alerts_engine = opts[:alerts_engine] || Engine.Alerts
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    pa_ess_zone = Map.fetch!(config, "pa_ess_zone")

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      pa_ess_id: {Map.fetch!(config, "pa_ess_loc"), pa_ess_zone},
      source_config: config |> Map.fetch!("source_config") |> Utilities.SourceConfig.parse!(),
      current_content_top: {nil, Content.Message.Empty.new()},
      current_content_bottom: {nil, Content.Message.Empty.new()},
      prediction_engine: prediction_engine,
      headway_engine: headway_engine,
      alerts_engine: alerts_engine,
      sign_updater: sign_updater,
      tick_bottom: 130,
      tick_top: 130,
      tick_read: 240 + offset(pa_ess_zone),
      expiration_seconds: 130,
      read_period_seconds: 240
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_run_loop(self())
    {:ok, sign}
  end

  def handle_info(:run_loop, sign) do
    sign_stop_ids =
      sign.source_config
      |> Signs.Utilities.SourceConfig.sign_stop_ids()

    sign_routes =
      sign.source_config
      |> Signs.Utilities.SourceConfig.sign_routes()

    alert_status = sign.alerts_engine.max_stop_status(sign_stop_ids, sign_routes)

    enabled? = Engine.Config.enabled?(sign.id)

    custom_text = Engine.Config.custom_text(sign.id)

    {top, bottom} = Utilities.Messages.get_messages(sign, enabled?, alert_status, custom_text)

    sign =
      sign
      |> Utilities.Updater.update_sign(top, bottom)
      |> Utilities.Reader.read_sign()
      |> do_expiration()
      |> decrement_ticks()

    schedule_run_loop(self())
    {:noreply, sign}
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Realtime unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  def schedule_run_loop(pid) do
    Process.send_after(pid, :run_loop, 1_000)
  end

  defp offset(zone) when zone in ["n"], do: 0
  defp offset(zone) when zone in ["s"], do: 60
  defp offset(zone) when zone in ["m"], do: 120
  defp offset(zone) when zone in ["e"], do: 30
  defp offset(zone) when zone in ["w"], do: 90
  defp offset(zone) when zone in ["c"], do: 150

  @spec do_expiration(Signs.Realtime.t()) :: Signs.Realtime.t()
  def do_expiration(%{tick_top: 0, tick_bottom: 0} = sign) do
    {_src, top} = sign.current_content_top
    {_src, bottom} = sign.current_content_bottom

    sign.sign_updater.update_sign(sign.pa_ess_id, top, bottom, sign.expiration_seconds + 15, :now)

    %{sign | tick_top: sign.expiration_seconds, tick_bottom: sign.expiration_seconds}
  end

  def do_expiration(%{tick_top: 0} = sign) do
    {_src, top} = sign.current_content_top

    sign.sign_updater.update_single_line(
      sign.pa_ess_id,
      "1",
      top,
      sign.expiration_seconds + 15,
      :now
    )

    %{sign | tick_top: sign.expiration_seconds}
  end

  def do_expiration(%{tick_bottom: 0} = sign) do
    {_src, bottom} = sign.current_content_bottom

    sign.sign_updater.update_single_line(
      sign.pa_ess_id,
      "2",
      bottom,
      sign.expiration_seconds + 15,
      :now
    )

    %{sign | tick_bottom: sign.expiration_seconds}
  end

  def do_expiration(sign), do: sign

  @spec decrement_ticks(Signs.Realtime.t()) :: Signs.Realtime.t()
  def decrement_ticks(sign) do
    %{
      sign
      | tick_bottom: sign.tick_bottom - 1,
        tick_top: sign.tick_top - 1,
        tick_read: sign.tick_read - 1
    }
  end
end
