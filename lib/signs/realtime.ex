defmodule Signs.Realtime do
  @moduledoc """
  A two-line sign that displays realtime countdown information from one or more sources. See
  Signs.Utilities.SourceConfig for information on the JSON format.
  """

  use GenServer
  require Logger

  alias Signs.Utilities
  alias Utilities.SourceConfig

  @announced_history_length 5

  @enforce_keys [
    :id,
    :text_id,
    :audio_id,
    :source_config,
    :current_content_top,
    :current_content_bottom,
    :prediction_engine,
    :headway_engine,
    :config_engine,
    :alerts_engine,
    :sign_updater,
    :last_update,
    :tick_read,
    :read_period_seconds
  ]

  defstruct @enforce_keys ++
              [
                :headway_stop_id,
                :current_time_fn,
                announced_arrivals: [],
                announced_approachings: [],
                announced_approachings_with_crowding: [],
                announced_passthroughs: [],
                uses_shuttles: true
              ]

  @type line_content :: Content.Message.t()
  @type sign_messages :: {line_content(), line_content()}
  @type predictions ::
          {[Predictions.Prediction.t()], [Predictions.Prediction.t()]}
          | [Predictions.Prediction.t()]

  @type t :: %__MODULE__{
          id: String.t(),
          text_id: PaEss.text_id(),
          audio_id: PaEss.audio_id(),
          source_config: SourceConfig.config() | {SourceConfig.config(), SourceConfig.config()},
          current_content_top: line_content(),
          current_content_bottom: line_content(),
          prediction_engine: module(),
          headway_engine: module(),
          config_engine: module(),
          alerts_engine: module(),
          current_time_fn: fun(),
          sign_updater: module(),
          last_update: DateTime.t(),
          tick_read: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          announced_arrivals: [Predictions.Prediction.trip_id()],
          announced_approachings: [Predictions.Prediction.trip_id()],
          announced_approachings_with_crowding: [Predictions.Prediction.trip_id()],
          announced_passthroughs: [Predictions.Prediction.trip_id()],
          uses_shuttles: boolean()
        }

  def start_link(%{"type" => "realtime"} = config, opts \\ []) do
    source_config = config |> Map.fetch!("source_config") |> SourceConfig.parse!()

    prediction_engine = opts[:prediction_engine] || Engine.Predictions
    headway_engine = opts[:headway_engine] || Engine.ScheduledHeadways
    config_engine = opts[:config_engine] || Engine.Config
    alerts_engine = opts[:alerts_engine] || Engine.Alerts
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      text_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "text_zone")},
      audio_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "audio_zones")},
      source_config: source_config,
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      prediction_engine: prediction_engine,
      headway_engine: headway_engine,
      config_engine: config_engine,
      alerts_engine: alerts_engine,
      current_time_fn:
        opts[:current_time_fn] ||
          fn ->
            time_zone = Application.get_env(:realtime_signs, :time_zone)
            DateTime.utc_now() |> DateTime.shift_zone!(time_zone)
          end,
      sign_updater: sign_updater,
      last_update: nil,
      tick_read: 240 + Map.fetch!(config, "read_loop_offset"),
      read_period_seconds: 240,
      headway_stop_id: Map.get(config, "headway_stop_id"),
      uses_shuttles: Map.get(config, "uses_shuttles", true)
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_run_loop(self())
    {:ok, sign}
  end

  def handle_info(:run_loop, sign) do
    sign_stop_ids = SourceConfig.sign_stop_ids(sign.source_config)
    sign_routes = SourceConfig.sign_routes(sign.source_config)
    alert_status = sign.alerts_engine.max_stop_status(sign_stop_ids, sign_routes)
    sign_config = sign.config_engine.sign_config(sign.id)
    current_time = sign.current_time_fn.()

    first_scheduled_departures =
      case sign.source_config do
        {top, bottom} ->
          {
            {sign.headway_engine.get_first_scheduled_departure(SourceConfig.sign_stop_ids(top)),
             top.headway_destination},
            {sign.headway_engine.get_first_scheduled_departure(
               SourceConfig.sign_stop_ids(bottom)
             ), bottom.headway_destination}
          }

        source ->
          {sign.headway_engine.get_first_scheduled_departure(sign_stop_ids),
           source.headway_destination}
      end

    predictions =
      case sign.source_config do
        {top, bottom} -> {fetch_predictions(top, sign), fetch_predictions(bottom, sign)}
        config -> fetch_predictions(config, sign)
      end

    {new_top, new_bottom} =
      Utilities.Messages.get_messages(
        predictions,
        sign,
        sign_config,
        current_time,
        alert_status,
        first_scheduled_departures
      )

    sign =
      sign
      |> announce_passthrough_trains(predictions)
      |> Utilities.Updater.update_sign(new_top, new_bottom, current_time)
      |> Utilities.Reader.do_interrupting_reads(
        sign.current_content_top,
        sign.current_content_bottom
      )
      |> Utilities.Reader.read_sign()
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

  defp fetch_predictions(%{sources: sources}, state) do
    Enum.flat_map(sources, fn source ->
      state.prediction_engine.for_stop(source.stop_id, source.direction_id)
    end)
  end

  @spec announce_passthrough_trains(Signs.Realtime.t(), predictions()) :: Signs.Realtime.t()
  defp announce_passthrough_trains(sign, predictions) do
    Utilities.Predictions.get_passthrough_train_audio(predictions)
    |> Enum.reduce(sign, fn audio, sign ->
      if audio.trip_id not in sign.announced_passthroughs do
        sign.sign_updater.send_audio(sign.audio_id, [audio], 5, 60, sign.id)

        update_in(sign.announced_passthroughs, fn list ->
          Enum.take([audio.trip_id | list], @announced_history_length)
        end)
      else
        sign
      end
    end)
  end

  @spec decrement_ticks(Signs.Realtime.t()) :: Signs.Realtime.t()
  def decrement_ticks(sign) do
    %{sign | tick_read: sign.tick_read - 1}
  end
end
