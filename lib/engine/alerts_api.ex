defmodule Engine.AlertsAPI do
  alias Engine.Alerts.Fetcher
  @callback max_stop_status([Fetcher.stop_id()], [Fetcher.route_id()]) :: Fetcher.stop_status()
end
