defmodule Signs.Countdown do
  @moduledoc """
  A two-line countdown sign that displays whether up to two trains are
  arriving, boarding, or how many minutes away they are.

  It knows about a single GTFS stop ID, and a hardcoded headsign. It displays
  on the sign that headsign, and uses the predictions engine to determine
  how long until the next two vehicles arrive at that GTFS stop ID.
  """

  use GenServer
  require Logger

  @enforce_keys [
    :id,
    :pa_ess_id,
    :gtfs_stop_id,
    :direction_id,
    :route_id,
    :headsign,
    :prediction_engine,
    :sign_updater,
    :read_sign_period_ms,
  ]

  defstruct @enforce_keys ++ [
    :current_content_bottom,
    :current_content_top,
    :bottom_timer,
    :top_timer,
  ]

  @type t :: %{
    id: String.t(),
    pa_ess_id: PaEss.id(),
    gtfs_stop_id: String.t(),
    direction_id: 0 | 1,
    route_id: String.t(),
    headsign: String.t(),
    prediction_engine: module(),
    sign_updater: module(),
    current_content_bottom: Content.Message.t() | nil,
    current_content_top: Content.Message.t() | nil,
    bottom_timer: reference() | nil,
    top_timer: reference() | nil,
    read_sign_period_ms: integer(),
  }

  @default_duration 120

  def start_link(%{"type" => "countdown"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    prediction_engine = opts[:prediction_engine] || Engine.Predictions

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      direction_id: config["direction_id"],
      route_id: config["route_id"],
      headsign: config["headsign"],
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      top_timer: nil,
      bottom_timer: nil,
      sign_updater: sign_updater,
      prediction_engine: prediction_engine,
      read_sign_period_ms: 4 * 60 * 1000,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_update(self())
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    {:ok, sign}
  end

  @spec handle_info(:update_content | :expire_top | :expire_bottom | :read_sign, t()) :: {:noreply, t()}
  def handle_info(:update_content, sign) do
    schedule_update(self())

    if Engine.Config.enabled?(sign.id) do
      {top, bottom} = get_messages(sign)
      sign = update_top(sign, top)
      sign = update_bottom(sign, bottom)
    else
      sign
    end

    {:noreply, sign}
  end

  def handle_info(:read_sign, sign) do
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    read_countdown(sign)
    {:noreply, sign}
  end

  def handle_info(:expire_top, sign) do
    {:noreply, %{sign | current_content_top: Content.Message.Empty.new()}}
  end

  def handle_info(:expire_bottom, sign) do
    {:noreply, %{sign | current_content_bottom: Content.Message.Empty.new()}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp get_messages(sign) do
    messages =
      sign.gtfs_stop_id
      |> sign.prediction_engine.for_stop(sign.direction_id)
      |> Predictions.Predictions.sort()
      |> Enum.take(2)
      |> Enum.map(& Content.Message.Predictions.new(&1, sign.headsign))

    {
      Enum.at(messages, 0, Content.Message.Empty.new()),
      Enum.at(messages, 1, Content.Message.Empty.new())
    }
  end

  defp update_top(%{current_content_top: same} = sign, same) do
    sign
  end
  defp update_top(sign, new_top) do
    sign.sign_updater.update_sign(sign.pa_ess_id, "1", new_top, @default_duration, :now)
    announce_arrival(new_top, sign)
    if sign.top_timer, do: Process.cancel_timer(sign.top_timer)
    timer = Process.send_after(self(), :expire_top, @default_duration * 1000 - 5000)
    %{sign | current_content_top: new_top, top_timer: timer}
  end

  defp update_bottom(%{current_content_bottom: same} = sign, same) do
    sign
  end
  defp update_bottom(sign, new_bottom) do
    sign.sign_updater.update_sign(sign.pa_ess_id, "2", new_bottom, @default_duration, :now)
    if sign.bottom_timer, do: Process.cancel_timer(sign.bottom_timer)
    timer = Process.send_after(self(), :expire_bottom, @default_duration * 1000 - 5000)
    %{sign | current_content_bottom: new_bottom, bottom_timer: timer}
  end

  defp announce_arrival(msg, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
      nil ->
        nil
    end
  end

  defp read_countdown(%{current_content_top: msg} = sign) do
    case Content.Audio.NextTrainCountdown.from_predictions_message(msg, :arrives) do
      %Content.Audio.NextTrainCountdown{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
      nil ->
        nil
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 1_000)
  end

  defp schedule_reading_sign(pid, ms) do
    Process.send_after(pid, :read_sign, ms)
  end
end
