defmodule RealtimeSignsWeb.Router do
  use RealtimeSignsWeb, :router

  require Logger

  pipeline :api do
    plug(:accepts, ["json"])
  end

  Logger.info("monitor sign uptime: #{inspect(Application.get_env(:realtime_signs, :monitor_sign_scu_uptime))}")
  if (Application.get_env(:realtime_signs, :monitor_sign_scu_uptime) === "true") do
    scope "/monitoring", RealtimeSignsWeb do
      pipe_through([:api])
      post("/uptime", MonitoringController, :uptime)
      get("/", MonitoringController, :index)
    end
  end
end
