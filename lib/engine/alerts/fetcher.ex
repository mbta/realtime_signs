defmodule Engine.Alerts.Fetcher do
  @type stop_id :: String.t()
  @type stop_status :: :shuttles_closed_station | :shuttles_transfer_station | :none

  @callback get_statuses() ::
              {:ok, %{:stop_statuses => %{stop_id() => stop_status()}, :route_statuses => %{}}}
              | {:error, any()}

  @spec higher_priority_status(stop_status(), stop_status()) :: stop_status()
  def higher_priority_status(status1, status2)
      when status1 == :shuttles_closed_station or status2 == :shuttles_closed_station do
    :shuttles_closed_station
  end

  def higher_priority_status(status1, status2)
      when status1 == :shuttles_transfer_station or status2 == :shuttles_transfer_station do
    :shuttles_transfer_station
  end

  def higher_priority_status(_status1, _status2) do
    :none
  end
end
