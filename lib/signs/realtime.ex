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
    :pa_ess_loc,
    :scu_id,
    :text_zone,
    :audio_zones,
    :source_config,
    :current_content_top,
    :current_content_bottom,
    :last_update,
    :tick_read,
    :read_period_seconds
  ]

  defstruct @enforce_keys ++
              [
                :headway_stop_id,
                :current_time_fn,
                announced_approachings: [],
                announced_passthroughs: [],
                announced_boardings: [],
                announced_stalls: [],
                announced_custom_text: nil,
                announced_alert: false,
                default_mode: :off,
                prev_prediction_keys: nil,
                prev_predictions: [],
                uses_shuttles: true,
                pa_message_plays: %{}
              ]

  @type predictions ::
          {[Predictions.Prediction.t()], [Predictions.Prediction.t()]}
          | [Predictions.Prediction.t()]

  @type t :: %__MODULE__{
          id: String.t(),
          pa_ess_loc: String.t(),
          scu_id: String.t(),
          text_zone: String.t(),
          audio_zones: [String.t()],
          source_config: SourceConfig.config() | {SourceConfig.config(), SourceConfig.config()},
          default_mode: Engine.Config.sign_config(),
          current_content_top: Content.Message.value(),
          current_content_bottom: Content.Message.value(),
          current_time_fn: fun(),
          last_update: DateTime.t(),
          tick_read: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          announced_approachings: [Predictions.Prediction.trip_id()],
          announced_passthroughs: [Predictions.Prediction.trip_id()],
          announced_boardings: [Predictions.Prediction.trip_id()],
          announced_stalls: [{Predictions.Prediction.trip_id(), non_neg_integer()}],
          announced_custom_text: String.t() | nil,
          prev_prediction_keys: [{String.t(), 0 | 1}] | nil,
          announced_alert: boolean(),
          prev_predictions: [Predictions.Prediction.t()],
          uses_shuttles: boolean(),
          pa_message_plays: %{integer() => DateTime.t()}
        }

  def start_link(%{"type" => "realtime"} = config) do
    source_config = config |> Map.fetch!("source_config") |> SourceConfig.parse!()

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      pa_ess_loc: Map.fetch!(config, "pa_ess_loc"),
      scu_id: Map.fetch!(config, "scu_id"),
      text_zone: Map.fetch!(config, "text_zone"),
      audio_zones: Map.fetch!(config, "audio_zones"),
      source_config: source_config,
      default_mode:
        config |> Map.get("default_mode") |> then(&if(&1 == "auto", do: :auto, else: :off)),
      current_content_top: "",
      current_content_bottom: "",
      current_time_fn: fn ->
        time_zone = Application.get_env(:realtime_signs, :time_zone)
        DateTime.utc_now() |> DateTime.shift_zone!(time_zone)
      end,
      last_update: nil,
      tick_read: 240 + Map.fetch!(config, "read_loop_offset"),
      read_period_seconds: 240,
      headway_stop_id: Map.get(config, "headway_stop_id"),
      uses_shuttles: Map.get(config, "uses_shuttles", true),
      pa_message_plays: %{}
    }

    GenServer.start_link(__MODULE__, sign, name: :"Signs/#{sign.id}")
  end

  def init(sign) do
    # This delay was chosen to be long enough to prevent individual sign crashes from restarting
    # the whole app, allowing some resilience against temporary external failures.
    Process.send_after(self(), :run_loop, 5000)
    {:ok, sign}
  end

  def handle_call({:play_pa_message, pa_message}, _from, sign) do
    {sign, should_play?} = Signs.Utilities.Audio.handle_pa_message_play(pa_message, sign)
    {:reply, {sign, should_play?}, sign}
  end

  def handle_info(:run_loop, sign) do
    sign_config = RealtimeSigns.config_engine().sign_config(sign.id, sign.default_mode)
    current_time = sign.current_time_fn.()

    alert_status =
      map_source_config(sign.source_config, fn config ->
        stop_ids = SourceConfig.sign_stop_ids(config)
        RealtimeSigns.alert_engine().min_stop_status(stop_ids)
      end)

    first_scheduled_departures =
      map_source_config(sign.source_config, fn config ->
        RealtimeSigns.headway_engine().get_first_scheduled_departure(
          SourceConfig.sign_stop_ids(config)
        )
      end)

    last_scheduled_departures =
      map_source_config(sign.source_config, fn config ->
        RealtimeSigns.headway_engine().get_last_scheduled_departure(
          SourceConfig.sign_stop_ids(config)
        )
      end)

    prev_predictions_lookup =
      for prediction <- sign.prev_predictions, into: %{} do
        {prediction_key(prediction), prediction}
      end

    recent_departures =
      map_source_config(sign.source_config, fn config ->
        SourceConfig.sign_stop_ids(config)
        |> Stream.flat_map(&RealtimeSigns.last_trip_engine().get_recent_departures(&1))
        |> Enum.max_by(fn {_, dt} -> dt end, DateTime, fn -> {nil, nil} end)
        |> elem(1)
      end)

    {predictions, all_predictions} =
      case sign.source_config do
        {top, bottom} ->
          top_predictions = fetch_predictions(top, prev_predictions_lookup)
          bottom_predictions = fetch_predictions(bottom, prev_predictions_lookup)
          {{top_predictions, bottom_predictions}, top_predictions ++ bottom_predictions}

        config ->
          predictions = fetch_predictions(config, prev_predictions_lookup)
          {predictions, predictions}
      end

    service_end_statuses_per_source =
      map_source_config(
        sign.source_config,
        &has_service_ended_for_source?(&1, current_time)
      )

    messages =
      Utilities.Messages.get_messages(
        predictions,
        sign,
        sign_config,
        current_time,
        alert_status,
        first_scheduled_departures,
        last_scheduled_departures,
        recent_departures,
        service_end_statuses_per_source
      )

    {new_top, new_bottom} = Utilities.Messages.render_messages(messages)

    sign =
      sign
      |> announce_passthrough_trains(predictions)
      |> Utilities.Updater.update_sign(new_top, new_bottom, current_time)
      |> Utilities.Reader.do_announcements(messages)
      |> Utilities.Reader.read_sign(messages)
      |> decrement_ticks()
      |> Map.put(:prev_predictions, all_predictions)

    Process.send_after(self(), :run_loop, 1000)
    {:noreply, sign}
  end

  def handle_info(msg, state) do
    Logger.warning("Signs.Realtime unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp has_service_ended_for_source?(source, current_time) do
    num_last_trips =
      SourceConfig.sign_stop_ids(source)
      |> Stream.flat_map(&RealtimeSigns.last_trip_engine().get_recent_departures(&1))
      |> Enum.count(fn {trip_id, departure_time} ->
        trip_departed?(departure_time, current_time) and
          RealtimeSigns.last_trip_engine().is_last_trip?(trip_id)
      end)

    # Red line trunk should wait for two last trips, one for each branch
    threshold = if(source.headway_group == "red_trunk", do: 2, else: 1)
    num_last_trips >= threshold
  end

  defp trip_departed?(departure_time, current_time) do
    # Use a 3 second buffer to make sure trips have fully departed
    DateTime.to_unix(current_time) - DateTime.to_unix(departure_time) > 3
  end

  defp prediction_key(prediction) do
    Map.take(prediction, [:stop_id, :route_id, :vehicle_id, :direction_id, :trip_id])
  end

  defp fetch_predictions(%{sources: sources} = config, prev_predictions_lookup) do
    for source <- sources,
        prediction <-
          RealtimeSigns.prediction_engine().for_stop(source.stop_id, source.direction_id) do
      prev = prev_predictions_lookup[prediction_key(prediction)]

      prediction
      |> prevent_countup(prev, :seconds_until_arrival)
      |> prevent_countup(prev, :seconds_until_departure)
      |> log_brd_to_arr(prev, config)
    end
  end

  # This is some temporary logging to check the prevalence of predictions going from BRD to ARR
  defp log_brd_to_arr(prediction, nil, _), do: prediction

  defp log_brd_to_arr(prediction, prev, %{terminal?: terminal?}) do
    if prediction.seconds_until_departure && prev.seconds_until_departure &&
         PaEss.Utilities.prediction_minutes(prediction, terminal?) == {:arriving, false} &&
         PaEss.Utilities.prediction_minutes(prev, terminal?) == {:boarding, false} do
      Logger.info("brd_to_arr: prediction=#{inspect(prediction)} prev=#{inspect(prev)}")
    end

    prediction
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
    Utilities.Predictions.get_passthrough_train_audio(predictions, sign)
    |> Enum.reduce(sign, fn audio, sign ->
      if audio.trip_id not in sign.announced_passthroughs do
        Signs.Utilities.Audio.send_audio(sign, [audio])

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

  defp map_source_config({top, bottom}, fun), do: {fun.(top), fun.(bottom)}
  defp map_source_config(config, fun), do: fun.(config)
end
