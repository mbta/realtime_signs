defmodule RealtimeSignsWeb.Router do
  use RealtimeSignsWeb, :router

  require Logger

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", RealtimeSignsWeb do
    pipe_through([:api])
    post("/uptime", MonitoringController, :uptime)
    get("/run_message_log_job/:date", MonitoringController, :run_message_log_job)
    get("/run_message_latency_report/:days", MonitoringController, :run_message_latency_report)
  end
end
