defmodule Engine.Alerts.Fetcher do
  @type stop_id :: String.t()
  @type route_id :: String.t()
  @type stop_status ::
          :shuttles_closed_station
          | :shuttles_transfer_station
          | :suspension
          | :station_closure
          | :none

  @callback get_statuses([String.t()]) ::
              {:ok,
               %{
                 :stop_statuses => %{stop_id() => stop_status()},
                 :route_statuses => %{route_id() => stop_status()}
               }}
              | {:error, any()}

  @alert_priority_map %{
    none: 0,
    suspension_transfer_station: 1,
    shuttles_transfer_station: 2,
    station_closure: 3,
    suspension_closed_station: 4,
    shuttles_closed_station: 5
  }

  @spec get_priority_level(stop_status()) :: number()
  def get_priority_level(status) do
    @alert_priority_map[status]
  end

  @spec higher_priority_status(stop_status(), stop_status()) :: stop_status()
  def higher_priority_status(status1, status2) do
    if @alert_priority_map[status1] >= @alert_priority_map[status2] do
      status1
    else
      status2
    end
  end
end
