import Config

config :realtime_signs, RealtimeSignsWeb.Endpoint,
  http: [port: System.get_env("MONITOR_SIGN_SCU_PORT")],
  url: [host: "localhost"],
  server: true

if config_env() == :prod do
  config :realtime_signs, RealtimeSignsWeb.Endpoint, secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
