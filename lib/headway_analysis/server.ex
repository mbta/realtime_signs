defmodule HeadwayAnalysis.Server do
  @moduledoc """
  Monitors a platform sign and logs all departures from that sign's stops, along with current
  headway values, for the purpose of tracking headway accuracy. See HeadwayAnalysis.Supervisor
  for the list of monitored signs.
  """
  use GenServer
  require Logger

  @enforce_keys [
    :sign_id,
    :headway_group,
    :stop_ids,
    :vehicles_present,
    :prediction_engine,
    :config_engine,
    :location_engine
  ]
  defstruct @enforce_keys

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
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
       prediction_engine: Engine.Predictions,
       config_engine: Engine.Config,
       location_engine: Engine.Locations
     }}
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    current_time =
      DateTime.utc_now() |> DateTime.shift_zone!(Application.get_env(:realtime_signs, :time_zone))

    {headway_low, headway_high} =
      case state.config_engine.headway_config(state.headway_group, current_time) do
        %Engine.Config.Headway{range_low: low, range_high: high} -> {low, high}
        nil -> {nil, nil}
      end

    revenue_vehicles = state.prediction_engine.revenue_vehicles()

    new_vehicles_present =
      for stop_id <- state.stop_ids,
          location <- state.location_engine.for_stop(stop_id),
          location.status == :stopped_at,
          into: MapSet.new() do
        location.vehicle_id
      end

    if MapSet.difference(state.vehicles_present, new_vehicles_present)
       |> Enum.any?(&(&1 in revenue_vehicles)) do
      Logger.info(
        "headway_analysis_departure: sign_id=#{state.sign_id} headway_low=#{headway_low} headway_high=#{headway_high}"
      )
    end

    {:noreply, %{state | vehicles_present: new_vehicles_present}}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
