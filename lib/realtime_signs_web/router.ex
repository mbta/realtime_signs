defmodule RealtimeSignsWeb.Router do
  use RealtimeSignsWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/monitoring", RealtimeSignsWeb do
    pipe_through([:api])
    post("/uptime", MonitoringController, :uptime)
    get("/", MonitoringController, :index)
  end
end
