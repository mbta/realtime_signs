defmodule Signs.Single do
  @moduledoc """
  A one-line countdown sign that displays the next train arrival as
  arriving, boarding, or how many minutes away they are.

  It knows about a single GTFS stop ID. It uses the
  predictions engine to determine how long until the next two vehicles
  arrive at that GTFS stop ID.
  """

  use GenServer
  require Logger

  @enforce_keys [
    :id,
    :pa_ess_id,
    :line_number,
    :gtfs_stop_id,
    :direction_id,
    :route_id,
    :prediction_engine,
    :sign_updater,
    :read_sign_period_ms,
    :countdown_verb,
    :announce_arriving?,
  ]

  defstruct @enforce_keys ++ [
    :current_content,
    :timer,
  ]

  @type t :: %{
    id: String.t(),
    pa_ess_id: PaEss.id(),
    line_number: String.t(),
    gtfs_stop_id: String.t(),
    direction_id: 0 | 1,
    route_id: String.t(),
    prediction_engine: module(),
    sign_updater: module(),
    current_content: Content.Message.t() | nil,
    timer: reference() | nil,
    read_sign_period_ms: integer(),
    countdown_verb: Content.Audio.NextTrainCountdown.verb(),
    announce_arriving?: boolean(),
  }

  @default_duration 120
  @sign_width 18

  def start_link(%{"type" => "single"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    prediction_engine = opts[:prediction_engine] || Engine.Predictions

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      line_number: config["line_number"],
      gtfs_stop_id: config["gtfs_stop_id"],
      direction_id: config["direction_id"],
      route_id: config["route_id"],
      current_content: Content.Message.Empty.new(),
      timer: nil,
      sign_updater: sign_updater,
      prediction_engine: prediction_engine,
      read_sign_period_ms: 4 * 60 * 1000,
      countdown_verb: config |> Map.fetch!("countdown_verb") |> String.to_atom(),
      announce_arriving?: Map.fetch!(config, "announce_arriving"),
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_update(self())
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    {:ok, sign}
  end

  @spec handle_info(:update_content | :expire | :read_sign, t()) :: {:noreply, t()}
  def handle_info(:update_content, sign) do
    schedule_update(self())
    message = if Engine.Config.enabled?(sign.id) do
      get_message(sign)
    else
      Content.Message.Empty.new()
    end

    sign = update(sign, message)
    {:noreply, sign}
  end

  def handle_info(:read_sign, sign) do
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    read_countdown(sign)
    {:noreply, sign}
  end

  def handle_info(:expire, sign) do
    {:noreply, %{sign | current_content: Content.Message.Empty.new()}}
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} #{inspect(state.id)} unknown message: #{inspect msg}")
    {:noreply, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 1_000)
  end

  defp schedule_reading_sign(pid, ms) do
    Process.send_after(pid, :read_sign, ms)
  end

  defp get_message(sign) do
    boarding? = Engine.Predictions.stopped_at?(sign.gtfs_stop_id)

    sign.gtfs_stop_id
    |> sign.prediction_engine.for_stop(sign.direction_id)
    |> Predictions.Predictions.sort()
    |> Enum.map(& Content.Message.Predictions.non_terminal(&1, @sign_width, boarding?))
    |> Enum.at(0, Content.Message.Empty.new())
  end

  @spec update(t(), Content.Message.t()) :: t()
  defp update(%{current_content: same} = sign, same) do
    sign
  end
  defp update(sign, new_text) do
    sign.sign_updater.update_single_line(sign.pa_ess_id, sign.line_number, new_text, @default_duration, :now)
    announce_arrival(new_text, sign)
    if sign.timer, do: Process.cancel_timer(sign.timer)
    timer = Process.send_after(self(), :expire, @default_duration * 1000 - 5000)
    %{sign | current_content: new_text, timer: timer}
  end

  defp announce_arrival(_msg, %{announce_arriving?: false}) do
    nil
  end
  defp announce_arrival(msg, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
      nil ->
        nil
    end
  end

  defp read_countdown(%{current_content: msg} = sign) do
    case Content.Audio.NextTrainCountdown.from_predictions_message(msg, sign.countdown_verb) do
      %Content.Audio.NextTrainCountdown{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
      nil ->
        nil
    end
  end
end
