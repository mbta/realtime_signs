use Mix.Config

config :realtime_signs, RealtimeSignsWeb.Endpoint,
  url: [host: "localhost"],
  server: true

config :logger,
  backends: [:console]
