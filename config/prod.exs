import Config

config :sentry,
  dsn: System.get_env("SENTRY_DSN") || "",
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: "production"
  },
  included_environments: [:prod]

config :logger, backends: [:console]

config :logger, :console, level: :info

config :realtime_signs,
  external_config_getter: ExternalConfig.S3,
  sign_updater_mod: MessageQueue,
  restart_fn: &System.restart/0

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, "default", 30}
  ]
