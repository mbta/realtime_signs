defmodule RealtimeSignsWeb.Router do
  use RealtimeSignsWeb, :router

  require Logger

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", RealtimeSignsWeb do
    pipe_through([:api])
    post("/uptime", MonitoringController, :uptime)
  end
end
