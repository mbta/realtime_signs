defmodule Signs.Headway do
  use GenServer
  require Logger
  @enforce_keys [
    :id,
    :pa_ess_id,
    :gtfs_stop_id,
    :route_id,
    :headsign,
    :headway_engine,
    :bridge_engine,
    :sign_updater,
    :read_sign_period_ms,
  ]

  defstruct @enforce_keys ++ [
    :bridge_id,
    :current_content_bottom,
    :current_content_top,
    :timer,
  ]

  @type t :: %{
    id: String.t(),
    pa_ess_id: PaEss.id(),
    gtfs_stop_id: String.t(),
    route_id: String.t(),
    headsign: String.t(),
    headway_engine: module(),
    bridge_engine: module(),
    sign_updater: module(),
    current_content_bottom: Content.Message.t() | nil,
    current_content_top: Content.Message.t() | nil,
    bridge_id: String.t(),
    timer: reference() | nil,
    read_sign_period_ms: integer(),
  }

  @default_duration 60

  def start_link(%{"type" => "headway"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    headway_engine = opts[:headway_engine] || Engine.Headways
    bridge_engine = opts[:bridge_engine] || Engine.Bridge

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      route_id: config["route_id"],
      headsign: config["headsign"],
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      bridge_id: config["bridge_id"],
      timer: nil,
      sign_updater: sign_updater,
      headway_engine: headway_engine,
      bridge_engine: bridge_engine,
      read_sign_period_ms: 5 * 60 * 1000,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    Engine.Headways.register(sign.gtfs_stop_id)
    schedule_update(self())
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    schedule_bridge_check(self())
    {:ok, sign}
  end

  def handle_info(:update_content, sign) do
    schedule_update(self())
    updated = %__MODULE__{
      sign |
      current_content_top: %Content.Message.Headways.Top{headsign: sign.headsign, vehicle_type: vehicle_type(sign.route_id)},
      current_content_bottom: bottom_content(sign.headway_engine.get_headways(sign.gtfs_stop_id))
    }

    send_update(sign, updated)
    {:noreply, updated}
  end
  def handle_info(:read_sign, sign) do
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    read_headway(sign)
    {:noreply, sign}
  end
  def handle_info(:expire, sign) do
    {:noreply, %{sign | current_content_top: Content.Message.Empty.new(), current_content_bottom: Content.Message.Empty.new()}}
  end

  def handle_info(:check_bridge, sign) do
    schedule_bridge_check(self())
    {:noreply, do_check_bridge(sign)}
  end

  defp do_check_bridge(%{bridge_id: nil} = sign) do
    sign
  end
  defp do_check_bridge(sign) do
    bridge_status = sign.bridge_engine.status(sign.bridge_id)
    case bridge_status do
      {"Raised", _duration} ->
        top_message = %Content.Message.Static{text: "Bridge is up"}
        bottom_message = %Content.Message.Static{text: "Expect SL3 delays"}
        send_update(sign, %{sign | current_content_top: top_message, current_content_bottom: bottom_message})
      _ ->
        sign
    end
  end

  defp send_update(%{current_content_bottom: same} = sign, %{current_content_bottom: same}) do
    sign
  end
  defp send_update(sign, %{current_content_top: new_top, current_content_bottom: new_bottom}) do
    sign.sign_updater.update_sign(sign.pa_ess_id, "1", new_top, @default_duration, :now)
    sign.sign_updater.update_sign(sign.pa_ess_id, "2", new_bottom, @default_duration, :now)
    if sign.timer, do: Process.cancel_timer(sign.timer)
    timer = Process.send_after(self(), :expire, @default_duration * 1000 - 5000)
    %{sign | current_content_top: new_top, current_content_bottom: new_bottom, timer: timer}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, @default_duration * 1000)
  end

  defp schedule_reading_sign(pid, ms) do
    Process.send_after(pid, :read_sign, ms)
  end

  def schedule_bridge_check(pid) do
    Process.send_after(pid, :check_bridge, 60 * 1000)
  end

  defp vehicle_type("Mattapan"), do: :trolley
  defp vehicle_type("743"), do: :bus

  defp bottom_content({:first_departure, range, first_departure}) do
    max_headway = Headway.ScheduleHeadway.max_headway(range)
    time_buffer = if max_headway, do: max_headway, else: 0
    current_time = Timex.now()
    if Headway.ScheduleHeadway.show_first_departure?(first_departure, current_time, time_buffer) do
      %Content.Message.Headways.Bottom{range: range}
    else
      Content.Message.Empty.new()
    end
  end
  defp bottom_content(range) do
    %Content.Message.Headways.Bottom{range: range}
  end

  defp read_headway(%{current_content_bottom: msg} = sign) do
    case Content.Audio.BusesToDestination.from_headway_message(msg, sign.headsign) do
      {english, spanish} ->
        sign.sign_updater.send_audio(sign.pa_ess_id, english, 5, 120)
        sign.sign_updater.send_audio(sign.pa_ess_id, spanish, 5, 120)
      nil ->
        nil
    end
  end
end
