import Config

config :logger, backends: [:console]

config :logger, :console, level: :info

config :realtime_signs,
  external_config_getter: ExternalConfig.S3,
  restart_fn: &System.restart/0

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}, :instance_role],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, "default", 30},
    :instance_role
  ]
