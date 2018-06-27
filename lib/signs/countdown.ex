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
  require Integer

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

  @default_expiration_seconds 130
  @expiration_overlap_seconds 115

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
    schedule_reading_sign(self(), sign.read_sign_period_ms + initial_offset(sign))
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

    try do
      sign = update_sign(sign, top, bottom)
    rescue
      e ->
        IO.inspect(e)
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

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} #{inspect(state.id)} unknown message: #{inspect msg}")
    {:noreply, state}
  end

  defp get_messages(sign) do
    stopped_at? = sign.prediction_engine.stopped_at?(sign.gtfs_stop_id)
    predictions =
      sign.gtfs_stop_id
      |> sign.prediction_engine.for_stop(sign.direction_id)
      |> Predictions.Predictions.sort()
      |> Enum.take(2)

    [p1, p2 | _rest] = predictions ++ [nil, nil]

    {get_message(p1, sign, stopped_at?), get_message(p2, sign, false)}
  end

  defp get_message(nil, _sign, _stopped_at) do
    Content.Message.Empty.new()
  end
  defp get_message(prediction, sign, stopped_at?) do
    if sign.terminal do
      Content.Message.Predictions.terminal(prediction, sign.headsign, stopped_at?)
    else
      Content.Message.Predictions.non_terminal(prediction, sign.headsign, stopped_at?)
    end
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
    update_response = sign.sign_updater.update_sign(sign.pa_ess_id, new_top, new_bottom, @default_expiration_seconds, :now, Timex.local())
    do_update_sign(update_response, sign, new_top, new_bottom)
  end

  defp do_update_sign({:ok, :sent}, sign, new_top, new_bottom) do
    announce_arrival(new_top, sign)
    if sign.top_timer, do: Process.cancel_timer(sign.top_timer)
    if sign.bottom_timer, do: Process.cancel_timer(sign.bottom_timer)
    top_timer = Process.send_after(self(), :expire_top, @expiration_overlap_seconds * 1000)
    bottom_timer = Process.send_after(self(), :expire_bottom, @expiration_overlap_seconds * 1000)
    %{sign | current_content_top: new_top, top_timer: top_timer, current_content_bottom: new_bottom, bottom_timer: bottom_timer}
  end
  defp do_update_sign({:error, _reason}, sign, _new_top, _new_bottom) do
    sign
  end

  defp update_top(%{current_content_top: same} = sign, same) do
    sign
  end
  defp update_top(sign, new_top) do
    sign.sign_updater.update_single_line(sign.pa_ess_id, "1", new_top, @default_expiration_seconds, :now, Timex.local())
    announce_arrival(new_top, sign)
    if sign.top_timer, do: Process.cancel_timer(sign.top_timer)
    timer = Process.send_after(self(), :expire_top, @expiration_overlap_seconds * 1000)
    %{sign | current_content_top: new_top, top_timer: timer}
  end

  defp update_bottom(%{current_content_bottom: same} = sign, same) do
    sign
  end
  defp update_bottom(sign, new_bottom) do
    sign.sign_updater.update_single_line(sign.pa_ess_id, "2", new_bottom, @default_expiration_seconds, :now, Timex.local())
    if sign.bottom_timer, do: Process.cancel_timer(sign.bottom_timer)
    timer = Process.send_after(self(), :expire_bottom, @expiration_overlap_seconds * 1000)
    %{sign | current_content_bottom: new_bottom, bottom_timer: timer}
  end

  defp announce_arrival(_msg, %{announce_arriving?: false}), do: nil
  defp announce_arrival(msg, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60, Timex.local())
      nil ->
        nil
    end
  end

  def initial_offset(sign) do
    offset_seed = case sign.gtfs_stop_id |> Integer.parse do
      {num, _} -> num
      _ -> 0
    end
    if Integer.is_even(offset_seed) do
      30 * 1_000
    else
      0
    end
  end

  defp read_countdown(%{current_content_top: msg} = sign) do
    case Content.Audio.NextTrainCountdown.from_predictions_message(msg, sign.countdown_verb) do
      %Content.Audio.NextTrainCountdown{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60, Timex.local())
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
