defmodule Signs.Realtime do
  @moduledoc """
  A two-line sign that displays realtime countdown information from one or more sources. See
  Signs.Utilities.SourceConfig for information on the JSON format.
  """

  use GenServer
  require Logger

  alias Signs.Utilities

  @announced_history_length 5

  @enforce_keys [
    :id,
    :text_id,
    :audio_id,
    :headway_group,
    :source_config,
    :current_content_top,
    :current_content_bottom,
    :prediction_engine,
    :headway_engine,
    :last_departure_engine,
    :config_engine,
    :alerts_engine,
    :sign_updater,
    :tick_top,
    :tick_bottom,
    :tick_audit,
    :tick_read,
    :expiration_seconds,
    :read_period_seconds
  ]

  defstruct @enforce_keys ++
              [
                :headway_stop_id,
                announced_arrivals: [],
                announced_approachings: [],
                announced_passthroughs: [],
                uses_shuttles: true
              ]

  @type line_content :: {Utilities.SourceConfig.source() | nil, Content.Message.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          text_id: PaEss.text_id(),
          audio_id: PaEss.audio_id(),
          headway_group: String.t(),
          source_config: Utilities.SourceConfig.config(),
          current_content_top: line_content(),
          current_content_bottom: line_content(),
          prediction_engine: module(),
          headway_engine: module(),
          last_departure_engine: module(),
          config_engine: module(),
          alerts_engine: module(),
          sign_updater: module(),
          tick_bottom: non_neg_integer(),
          tick_top: non_neg_integer(),
          tick_audit: non_neg_integer(),
          tick_read: non_neg_integer(),
          expiration_seconds: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          announced_arrivals: [Predictions.Prediction.trip_id()],
          announced_approachings: [Predictions.Prediction.trip_id()],
          announced_passthroughs: [Predictions.Prediction.trip_id()],
          uses_shuttles: boolean()
        }

  def start_link(%{"type" => "realtime"} = config, opts \\ []) do
    source_config = config |> Map.fetch!("source_config") |> Utilities.SourceConfig.parse!()

    prediction_engine = opts[:prediction_engine] || Engine.Predictions
    headway_engine = opts[:headway_engine] || Engine.ScheduledHeadways
    config_engine = opts[:config_engine] || Engine.Config
    last_departure_engine = opts[:last_departure_engine] || Engine.Departures
    alerts_engine = opts[:alerts_engine] || Engine.Alerts
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      text_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "text_zone")},
      audio_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "audio_zones")},
      headway_group: Map.fetch!(config, "headway_group"),
      source_config: source_config,
      current_content_top: {nil, Content.Message.Empty.new()},
      current_content_bottom: {nil, Content.Message.Empty.new()},
      prediction_engine: prediction_engine,
      headway_engine: headway_engine,
      last_departure_engine: last_departure_engine,
      config_engine: config_engine,
      alerts_engine: alerts_engine,
      sign_updater: sign_updater,
      tick_bottom: 130,
      tick_top: 130,
      tick_audit: 60,
      tick_read: 240 + Map.fetch!(config, "read_loop_offset"),
      expiration_seconds: 130,
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
    sign_stop_ids =
      sign.source_config
      |> Signs.Utilities.SourceConfig.sign_stop_ids()

    sign_routes =
      sign.source_config
      |> Signs.Utilities.SourceConfig.sign_routes()

    alert_status = sign.alerts_engine.max_stop_status(sign_stop_ids, sign_routes)
    sign_config = sign.config_engine.sign_config(sign.id)
    time_zone = Application.get_env(:realtime_signs, :time_zone)
    {:ok, current_time} = DateTime.utc_now() |> DateTime.shift_zone(time_zone)

    {top, bottom} =
      Utilities.Messages.get_messages(
        sign,
        sign_config,
        current_time,
        alert_status
      )

    sign =
      sign
      |> announce_passthrough_trains()
      |> Utilities.Updater.update_sign(top, bottom)
      |> Utilities.Reader.read_sign()
      |> log_headway_accuracy()
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

  @spec announce_passthrough_trains(Signs.Realtime.t()) :: Signs.Realtime.t()
  defp announce_passthrough_trains(sign) do
    sign
    |> Utilities.Predictions.get_passthrough_train_audio()
    |> Enum.reduce(sign, fn audio, sign ->
      if audio.trip_id not in sign.announced_passthroughs do
        sign.sign_updater.send_audio(sign.audio_id, audio, 5, 60)

        update_in(sign.announced_passthroughs, fn list ->
          Enum.take([audio.trip_id | list], @announced_history_length)
        end)
      else
        sign
      end
    end)
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
        tick_audit: sign.tick_audit - 1,
        tick_read: sign.tick_read - 1
    }
  end

  @spec log_headway_accuracy(Signs.Realtime.t()) :: Signs.Realtime.t()
  def log_headway_accuracy(
        %{
          tick_audit: 0,
          source_config: source_config,
          current_content_bottom:
            {_source_config,
             %Content.Message.Headways.Bottom{
               range: range,
               prev_departure_mins: last_departure
             }}
        } = sign
      )
      when not is_nil(last_departure) do
    max_headway = Headway.HeadwayDisplay.max_headway(range)

    Logger.info(
      "headway_accuracy_check stop_id=#{List.first(Signs.Utilities.SourceConfig.sign_stop_ids(source_config))} headway_max=#{max_headway} last_departure=#{last_departure} in_range=#{max_headway > last_departure}"
    )

    %{sign | tick_audit: 60}
  end

  def log_headway_accuracy(%{tick_audit: 0} = sign) do
    %{sign | tick_audit: 60}
  end

  def log_headway_accuracy(sign) do
    sign
  end
end
