use Mix.Config

config :logger,
  backends: [:console]

config :realtime_signs, http_pool_config: %{
    :default => [size: 25]
  }
