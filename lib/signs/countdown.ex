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
    :route_id,
    :headsign,
    :prediction_engine,
    :sign_updater
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
    route_id: String.t(),
    headsign: String.t(),
    prediction_engine: module(),
    sign_updater: module(),
    current_content_bottom: Content.Message.t() | nil,
    current_content_top: Content.Message.t() | nil,
    bottom_timer: reference() | nil,
    top_timer: reference() | nil,
  }

  @default_duration 60

  def start_link(%{"type" => "countdown"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    prediction_engine = opts[:prediction_engine] || Engine.Predictions

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      route_id: config["route_id"],
      headsign: config["headsign"],
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      top_timer: nil,
      bottom_timer: nil,
      sign_updater: sign_updater,
      prediction_engine: prediction_engine,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_update(self())
    {:ok, sign}
  end

  @spec handle_info(:update_content | :expire_top | :expire_bottom, t()) :: {:noreply, t()}
  def handle_info(:update_content, sign) do
    schedule_update(self())

    {top, bottom} = get_messages(sign)
    sign = update_top(sign, top)
    sign = update_bottom(sign, bottom)

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

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 1_000)
  end

  defp get_messages(sign) do
    messages =
      sign.gtfs_stop_id
      |> sign.prediction_engine.for_stop()
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
end
