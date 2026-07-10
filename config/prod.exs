import Config

config :logger, :console, level: :info

config :realtime_signs,
  external_config_getter: ExternalConfig.S3
