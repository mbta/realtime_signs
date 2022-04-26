defmodule RealtimeSignsWeb.Router do
  use RealtimeSignsWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/monitoring", RealtimeSignsWeb do
    pipe_through([:api])
    post("/uptime/sign", MonitoringController, :sign_uptime)
    post("/updtime/scu", MonitoringController, :scu_uptime)
    get("/", MonitoringController, :index)
  end
end
