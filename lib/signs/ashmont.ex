defmodule Signs.Ashmont do
  @moduledoc """
  A one-line countdown sign that displays the next train arrival as
  arriving, boarding, or how many minutes away they are.

  It knows about a single GTFS stop ID, and a hardcoded headsign. It displays
  on the sign that headsign, and uses the predictions engine to determine
  how long until the next two vehicles arrive at that GTFS stop ID.
  """

  use GenServer
  require Logger

  @line_number "2"

  @enforce_keys [
    :id,
    :pa_ess_id,
    :gtfs_stop_id,
    :route_id,
    :headsign,
    :prediction_engine,
    :sign_updater,
  ]

  defstruct @enforce_keys ++ [
    :current_content,
    :timer,
  ]

  @type t :: %{
    id: String.t(),
    pa_ess_id: PaEss.id(),
    gtfs_stop_id: String.t(),
    route_id: String.t(),
    headsign: String.t(),
    prediction_engine: module(),
    sign_updater: module(),
    current_content: Content.Message.t() | nil,
    timer: reference() | nil,
  }

  @default_duration 60

  def start_link(%{"type" => "ashmont"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    prediction_engine = opts[:prediction_engine] || Engine.Predictions

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      route_id: config["route_id"],
      headsign: config["headsign"],
      current_content: Content.Message.Empty.new(),
      timer: nil,
      sign_updater: sign_updater,
      prediction_engine: prediction_engine,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_update(self())
    {:ok, sign}
  end

  @spec handle_info(:update_content | :expire, t()) :: {:noreply, t()}
  def handle_info(:update_content, sign) do
    schedule_update(self())

    message = get_message(sign)
    sign = update(sign, message)

    {:noreply, sign}
  end

  def handle_info(:expire, sign) do
    {:noreply, %{sign | current_content: Content.Message.Empty.new()}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 1_000)
  end

  defp get_message(sign) do
    messages =
      sign.gtfs_stop_id
      |> sign.prediction_engine.for_stop()
      |> Predictions.Predictions.sort()
      |> Enum.map(& Content.Message.Predictions.new(&1, sign.headsign))

      Enum.at(messages, 0, Content.Message.Empty.new())
  end

  defp update(%{current_content: same} = sign, same) do
    sign
  end
  defp update(sign, new_text) do
    sign.sign_updater.update_sign(sign.pa_ess_id, @line_number, new_text, @default_duration, :now)
    if sign.timer, do: Process.cancel_timer(sign.timer)
    timer = Process.send_after(self(), :expire, @default_duration * 1000 - 5000)
    %{sign | current_content: new_text, timer: timer}
  end
end
