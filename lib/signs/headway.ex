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
    :sign_updater
  ]

  defstruct @enforce_keys ++ [
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
    sign_updater: module(),
    current_content_bottom: Content.Message.t() | nil,
    current_content_top: Content.Message.t() | nil,
    timer: reference() | nil,
  }

  @default_duration 6

  def start_link(%{"type" => "headway"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    headway_engine = opts[:headway_engine] || Engine.Headways

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      route_id: config["route_id"],
      headsign: config["headsign"],
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      timer: nil,
      sign_updater: sign_updater,
      headway_engine: headway_engine,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    Engine.Headways.register(sign.gtfs_stop_id)
    schedule_update(self())
    {:ok, sign}
  end

  def handle_info(:update_content, sign) do
    schedule_update(self())
    updated = %__MODULE__{
      sign |
      current_content_top: %Content.Message.Headways.Top{headsign: sign.headsign, vehicle_type: vehicle_type(sign.route_id)},
      current_content_bottom: %Content.Message.Headways.Bottom{range: sign.headway_engine.get_headways(sign.gtfs_stop_id)}
    }

    send_update(sign, updated)
    {:noreply, updated}
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

  def handle_info(:expire, sign) do
    {:noreply, %{sign | current_content_top: Content.Message.Empty.new(), current_content_bottom: Content.Message.Empty.new()}}
  end

  defp vehicle_type("Mattapan"), do: "Trolley"
  defp vehicle_type("743"), do: "Buses"
end
