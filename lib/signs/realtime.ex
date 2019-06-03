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
    :text_id,
    :audio_id,
    :source_config,
    :current_content_top,
    :current_content_bottom,
    :prediction_engine,
    :headway_engine,
    :alerts_engine,
    :bridge_engine,
    :sign_updater,
    :tick_top,
    :tick_bottom,
    :tick_read,
    :expiration_seconds,
    :read_period_seconds
  ]

  defstruct @enforce_keys ++ [:bridge_id, announced_arrivals: [], announced_approachings: []]

  @type line_content :: {Utilities.SourceConfig.source() | nil, Content.Message.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          text_id: PaEss.text_id(),
          audio_id: PaEss.audio_id(),
          source_config: Utilities.SourceConfig.config(),
          current_content_top: line_content(),
          current_content_bottom: line_content(),
          prediction_engine: module(),
          headway_engine: module(),
          alerts_engine: module(),
          bridge_engine: module(),
          sign_updater: module(),
          tick_bottom: non_neg_integer(),
          tick_top: non_neg_integer(),
          tick_read: non_neg_integer(),
          expiration_seconds: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          bridge_id: Engine.Bridge.bridge_id() | nil,
          announced_arrivals: [Predictions.Prediction.trip_id()],
          announced_approachings: [Predictions.Prediction.trip_id()]
        }

  def start_link(%{"type" => "realtime"} = config, opts \\ []) do
    prediction_engine = opts[:prediction_engine] || Engine.Predictions
    headway_engine = opts[:headway_engine] || Engine.Headways
    alerts_engine = opts[:alerts_engine] || Engine.Alerts
    bridge_engine = opts[:bridge_engine] || Engine.Bridge
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      text_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "text_zone")},
      audio_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "audio_zones")},
      source_config: config |> Map.fetch!("source_config") |> Utilities.SourceConfig.parse!(),
      current_content_top: {nil, Content.Message.Empty.new()},
      current_content_bottom: {nil, Content.Message.Empty.new()},
      prediction_engine: prediction_engine,
      headway_engine: headway_engine,
      alerts_engine: alerts_engine,
      bridge_engine: bridge_engine,
      sign_updater: sign_updater,
      tick_bottom: 130,
      tick_top: 130,
      tick_read: 240 + Map.fetch!(config, "read_loop_offset"),
      expiration_seconds: 130,
      read_period_seconds: 240,
      bridge_id: Map.get(config, "bridge_id")
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

    mode = Content.Message.Alert.NoService.transit_mode_for_routes(sign_routes)

    bridge_state =
      if sign.bridge_id do
        Engine.Bridge.status(sign.bridge_id)
      else
        nil
      end

    {top, bottom} =
      Utilities.Messages.get_messages(
        sign,
        enabled?,
        alert_status,
        custom_text,
        mode,
        bridge_state
      )

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

  @spec do_expiration(Signs.Realtime.t()) :: Signs.Realtime.t()
  def do_expiration(%{tick_top: 0, tick_bottom: 0} = sign) do
    {_src, top} = sign.current_content_top
    {_src, bottom} = sign.current_content_bottom

    sign.sign_updater.update_sign(sign.text_id, top, bottom, sign.expiration_seconds + 15, :now)

    %{sign | tick_top: sign.expiration_seconds, tick_bottom: sign.expiration_seconds}
  end

  def do_expiration(%{tick_top: 0} = sign) do
    {_src, top} = sign.current_content_top

    sign.sign_updater.update_single_line(
      sign.text_id,
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
      sign.text_id,
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
