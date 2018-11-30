defmodule Engine.Alerts.Fetcher do
  @type stop_id :: String.t()
  @type stop_status :: :shuttles_closed_station | :shuttles_transfer_station

  @callback get_stop_statuses() :: {:ok, %{stop_id() => stop_status()}} | {:error, any()}
end
