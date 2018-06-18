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
    :countdown_verb,
    :terminal,
    :prediction_engine,
    :sign_updater,
    :read_sign_period_ms,
  ]

  defstruct @enforce_keys ++ [
    :current_content_bottom,
    :current_content_top,
    :bottom_timer,
    :top_timer,
    announce_arriving?: true
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
    countdown_verb: String.t(),
    terminal: boolean,
    bottom_timer: reference() | nil,
    top_timer: reference() | nil,
    read_sign_period_ms: integer(),
    announce_arriving?: boolean
  }

  @default_duration 130

  def start_link(%{"type" => "countdown"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    prediction_engine = opts[:prediction_engine] || Engine.Predictions

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      pa_ess_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "pa_ess_zone")},
      gtfs_stop_id: Map.fetch!(config, "gtfs_stop_id"),
      direction_id: Map.fetch!(config, "direction_id"),
      route_id: Map.fetch!(config, "route_id"),
      headsign: Map.fetch!(config, "headsign"),
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      terminal: Map.fetch!(config, "terminal"),
      countdown_verb: config |> Map.fetch!("countdown_verb") |> String.to_atom(),
      top_timer: nil,
      bottom_timer: nil,
      sign_updater: sign_updater,
      prediction_engine: prediction_engine,
      read_sign_period_ms: 4 * 60 * 1000,
      announce_arriving?: Map.get(config, "announce_arriving", true)
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

    {top, bottom} = if Engine.Config.enabled?(sign.id) do
      get_messages(sign)
    else
      {Content.Message.Empty.new(), Content.Message.Empty.new()}
    end

    sign = update_sign(sign, top, bottom)

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
    boarding? = Engine.Predictions.stopped_at?(sign.gtfs_stop_id)
    messages =
      sign.gtfs_stop_id
      |> sign.prediction_engine.for_stop(sign.direction_id)
      |> Predictions.Predictions.sort()
      |> Enum.take(2)
      |> Enum.map(fn prediction ->
                    if sign.terminal do
                      Content.Message.Predictions.terminal(prediction, sign.headsign, boarding?)
                    else
                      Content.Message.Predictions.non_terminal(prediction, sign.headsign, boarding?)
                    end
                  end)


    {
      Enum.at(messages, 0, Content.Message.Empty.new()),
      Enum.at(messages, 1, Content.Message.Empty.new())
    }
  end

  defp update_sign(%{current_content_top: same_top, current_content_bottom: same_bottom} = sign, same_top, same_bottom) do
    sign
  end
  defp update_sign(%{current_content_top: _old_top, current_content_bottom: same_bottom} = sign, new_top, same_bottom) do
    update_top(sign, new_top)
  end
  defp update_sign(%{current_content_top: same_top, current_content_bottom: _old_bottom} = sign, same_top, new_bottom) do
    update_bottom(sign, new_bottom)
  end
  defp update_sign(sign, new_top, new_bottom) do
    {:ok, :sent} = sign.sign_updater.update_sign(sign.pa_ess_id, new_top, new_bottom, @default_duration, :now)
    announce_arrival(new_top, sign)
    if sign.top_timer, do: Process.cancel_timer(sign.top_timer)
    if sign.bottom_timer, do: Process.cancel_timer(sign.bottom_timer)
    top_timer = Process.send_after(self(), :expire_top, @default_duration * 1000 - 15000)
    bottom_timer = Process.send_after(self(), :expire_bottom, @default_duration * 1000 - 15000)
    %{sign | current_content_top: new_top, top_timer: top_timer, current_content_bottom: new_bottom, bottom_timer: bottom_timer}
  end

  defp update_top(%{current_content_top: same} = sign, same) do
    sign
  end
  defp update_top(sign, new_top) do
    sign.sign_updater.update_single_line(sign.pa_ess_id, "1", new_top, @default_duration, :now)
    announce_arrival(new_top, sign)
    if sign.top_timer, do: Process.cancel_timer(sign.top_timer)
    timer = Process.send_after(self(), :expire_top, @default_duration * 1000 - 15000)
    %{sign | current_content_top: new_top, top_timer: timer}
  end

  defp update_bottom(%{current_content_bottom: same} = sign, same) do
    sign
  end
  defp update_bottom(sign, new_bottom) do
    sign.sign_updater.update_single_line(sign.pa_ess_id, "2", new_bottom, @default_duration, :now)
    if sign.bottom_timer, do: Process.cancel_timer(sign.bottom_timer)
    timer = Process.send_after(self(), :expire_bottom, @default_duration * 1000 - 15000)
    %{sign | current_content_bottom: new_bottom, bottom_timer: timer}
  end

  defp announce_arrival(_msg, %{announce_arriving?: false}), do: nil
  defp announce_arrival(msg, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
      nil ->
        nil
    end
  end

  defp read_countdown(%{current_content_top: msg} = sign) do
    case Content.Audio.NextTrainCountdown.from_predictions_message(msg, sign.countdown_verb) do
      %Content.Audio.NextTrainCountdown{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
      nil ->
        nil
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 3_000)
  end

  defp schedule_reading_sign(pid, ms) do
    Process.send_after(pid, :read_sign, ms)
  end
end
