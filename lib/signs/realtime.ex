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
    :location_engine,
    :headway_engine,
    :config_engine,
    :alerts_engine,
    :last_trip_engine,
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
                announced_boardings: [],
                announced_stalls: [],
                announced_custom_text: nil,
                announced_alert: false,
                prev_prediction_keys: nil,
                prev_predictions: [],
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
          current_content_top: Content.Message.value(),
          current_content_bottom: Content.Message.value(),
          prediction_engine: module(),
          location_engine: module(),
          headway_engine: module(),
          config_engine: module(),
          alerts_engine: module(),
          last_trip_engine: module(),
          current_time_fn: fun(),
          sign_updater: module(),
          last_update: DateTime.t(),
          tick_read: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          announced_arrivals: [Predictions.Prediction.trip_id()],
          announced_approachings: [Predictions.Prediction.trip_id()],
          announced_approachings_with_crowding: [Predictions.Prediction.trip_id()],
          announced_passthroughs: [Predictions.Prediction.trip_id()],
          announced_boardings: [Predictions.Prediction.trip_id()],
          announced_stalls: [{Predictions.Prediction.trip_id(), non_neg_integer()}],
          announced_custom_text: String.t() | nil,
          prev_prediction_keys: [{String.t(), 0 | 1}] | nil,
          announced_alert: boolean(),
          prev_predictions: [Predictions.Prediction.t()],
          uses_shuttles: boolean()
        }

  def start_link(%{"type" => "realtime"} = config, opts \\ []) do
    source_config = config |> Map.fetch!("source_config") |> SourceConfig.parse!()

    prediction_engine = opts[:prediction_engine] || Engine.Predictions
    headway_engine = opts[:headway_engine] || Engine.ScheduledHeadways
    config_engine = opts[:config_engine] || Engine.Config
    alerts_engine = opts[:alerts_engine] || Engine.Alerts
    last_trip_engine = opts[:last_trip_engine] || Engine.LastTrip
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      text_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "text_zone")},
      audio_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "audio_zones")},
      source_config: source_config,
      current_content_top: "",
      current_content_bottom: "",
      prediction_engine: prediction_engine,
      location_engine: opts[:location_engine] || Engine.Locations,
      headway_engine: headway_engine,
      config_engine: config_engine,
      alerts_engine: alerts_engine,
      last_trip_engine: last_trip_engine,
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

    GenServer.start_link(__MODULE__, sign, name: :"Signs/#{sign.id}")
  end

  def init(sign) do
    # This delay was chosen to be long enough to prevent individual sign crashes from restarting
    # the whole app, allowing some resilience against temporary external failures.
    Process.send_after(self(), :run_loop, 5000)
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

    prev_predictions_lookup =
      for prediction <- sign.prev_predictions, into: %{} do
        {prediction_key(prediction), prediction}
      end

    {predictions, all_predictions} =
      case sign.source_config do
        {top, bottom} ->
          top_predictions = fetch_predictions(top, prev_predictions_lookup, sign)
          bottom_predictions = fetch_predictions(bottom, prev_predictions_lookup, sign)
          {{top_predictions, bottom_predictions}, top_predictions ++ bottom_predictions}

        config ->
          predictions = fetch_predictions(config, prev_predictions_lookup, sign)
          {predictions, predictions}
      end

    service_end_statuses_per_source =
      if SourceConfig.multi_source?(sign.source_config) do
        {top_source, bottom_source} = sign.source_config

        {has_service_ended_for_source?(sign, top_source, current_time),
         has_service_ended_for_source?(sign, bottom_source, current_time)}
      else
        has_service_ended_for_source?(sign, sign.source_config, current_time)
      end

    {new_top, new_bottom} =
      Utilities.Messages.get_messages(
        predictions,
        sign,
        sign_config,
        current_time,
        alert_status,
        first_scheduled_departures,
        service_end_statuses_per_source
      )

    sign =
      sign
      |> announce_passthrough_trains(predictions)
      |> Utilities.Updater.update_sign(new_top, new_bottom, current_time)
      |> Utilities.Reader.do_announcements(new_top, new_bottom)
      |> Utilities.Reader.read_sign(new_top, new_bottom)
      |> decrement_ticks()
      |> Map.put(:prev_predictions, all_predictions)

    Process.send_after(self(), :run_loop, 1000)
    {:noreply, sign}
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Realtime unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp has_service_ended_for_source?(sign, source, current_time) do
    stop_ids = SourceConfig.sign_stop_ids(source)

    # Red Line trunk stops will have two last trips in both directions
    if Enum.all?(stop_ids, &is_red_line_trunk_stop?/1),
      do: Enum.count(stop_ids, &has_last_trip_departed_stop?(&1, sign, current_time)) >= 2,
      else: Enum.any?(stop_ids, &has_last_trip_departed_stop?(&1, sign, current_time))
  end

  defp has_last_trip_departed_stop?(stop_id, sign, current_time) do
    case sign.last_trip_engine.get_recent_departures(stop_id) do
      nil ->
        false

      recent_departures ->
        Enum.any?(recent_departures, fn {trip_id, timestamp} ->
          # Use a 5 second buffer to make sure trips have fully departed
          DateTime.to_unix(current_time) - timestamp > 5 and
            sign.last_trip_engine.is_last_trip?(trip_id)
        end)
    end
  end

  defp prediction_key(prediction) do
    Map.take(prediction, [:stop_id, :route_id, :vehicle_id, :direction_id, :trip_id])
  end

  defp fetch_predictions(%{sources: sources}, prev_predictions_lookup, state) do
    for source <- sources,
        prediction <- state.prediction_engine.for_stop(source.stop_id, source.direction_id) do
      prev = prev_predictions_lookup[prediction_key(prediction)]

      prediction
      |> prevent_countup(prev, :seconds_until_arrival)
      |> prevent_countup(prev, :seconds_until_departure)
    end
  end

  defp prevent_countup(prediction, nil, _), do: prediction

  defp prevent_countup(prediction, prev, key) do
    seconds = Map.get(prediction, key)
    prev_seconds = Map.get(prev, key)

    if seconds && prev_seconds && round(seconds / 60) == round(prev_seconds / 60) + 1 do
      Map.put(prediction, key, Map.get(prev, key))
    else
      prediction
    end
  end

  @spec announce_passthrough_trains(Signs.Realtime.t(), predictions()) :: Signs.Realtime.t()
  defp announce_passthrough_trains(sign, predictions) do
    Utilities.Predictions.get_passthrough_train_audio(predictions)
    |> Enum.reduce(sign, fn audio, sign ->
      if audio.trip_id not in sign.announced_passthroughs do
        sign.sign_updater.send_audio(
          sign.audio_id,
          [Content.Audio.to_params(audio)],
          5,
          60,
          sign.id,
          [Utilities.Audio.audio_log_details(audio)]
        )

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

  defp is_red_line_trunk_stop?(stop_id) do
    stop_id in [
      "70061",
      "Alewife-01",
      "Alewife-02",
      "70064",
      "70063",
      "70066",
      "70065",
      "70068",
      "70067",
      "70070",
      "70069",
      "70072",
      "70071",
      "70074",
      "70073",
      "70076",
      "70075",
      "70078",
      "70077",
      "70080",
      "70079",
      "70082",
      "70081",
      "70084",
      "70083",
      "70085",
      "70095",
      "70086",
      "70096"
    ]
  end
end
