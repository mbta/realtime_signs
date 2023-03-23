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

    get(
      "/run_message_latency_report/:start_date/:days",
      MonitoringController,
      :run_message_latency_report
    )

    get("/update_active_headend/:ip", MonitoringController, :update_active_headend)
  end
end
