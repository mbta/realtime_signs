defmodule Engine.Alerts.Fetcher do
  @type stop_id :: String.t()
  @type stop_status :: :shuttles_closed | :shuttles_endpoint | :shuttles_terminal

  @callback get_stop_statuses() :: {:ok, %{stop_id() => stop_status()}} | {:error, any()}
end
