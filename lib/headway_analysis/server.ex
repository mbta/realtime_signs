defmodule HeadwayAnalysis.Server do
  @moduledoc """
  Monitors a platform sign and logs all departures from that sign's stops, along with current
  headway values, for the purpose of tracking headway accuracy. See HeadwayAnalysis.Supervisor
  for the list of monitored signs.
  """
  use GenServer
  require Logger

  @enforce_keys [:sign_id, :headway_group, :stop_ids, :vehicles_present, :trip_lookup]
  defstruct @enforce_keys

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: :"HeadwayAnalysis/#{config["id"]}")
  end

  @impl true
  def init(config) do
    schedule_update(self())

    {:ok,
     %__MODULE__{
       sign_id: config["id"],
       headway_group: config["source_config"]["headway_group"],
       stop_ids: Enum.map(config["source_config"]["sources"], & &1["stop_id"]),
       vehicles_present: MapSet.new(),
       trip_lookup: MapSet.new()
     }}
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    current_time =
      DateTime.utc_now() |> DateTime.shift_zone!(Application.get_env(:realtime_signs, :time_zone))

    {headway_low, headway_high} =
      case RealtimeSigns.config_engine().headway_config(state.headway_group, current_time) do
        %Engine.Config.Headway{range_low: low, range_high: high} -> {low, high}
        nil -> {nil, nil}
      end

    revenue_vehicles = RealtimeSigns.prediction_engine().revenue_vehicles()

    present_vehicle_locations =
      Enum.flat_map(state.stop_ids, &RealtimeSigns.location_engine().for_stop(&1))
      |> Enum.filter(&(&1.status == :stopped_at))

    new_vehicles_present = MapSet.new(present_vehicle_locations, & &1.vehicle_id)
    new_trip_lookup = Map.new(present_vehicle_locations, &{&1.vehicle_id, &1.trip_id})

    MapSet.difference(state.vehicles_present, new_vehicles_present)
    |> Enum.filter(&(&1 in revenue_vehicles))
    |> Enum.each(fn vehicle_id ->
      Logger.info(
        "headway_analysis_departure: sign_id=#{inspect(state.sign_id)} trip_id=#{inspect(state.trip_lookup[vehicle_id])} headway_low=#{headway_low} headway_high=#{headway_high}"
      )
    end)

    {:noreply, %{state | vehicles_present: new_vehicles_present, trip_lookup: new_trip_lookup}}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
