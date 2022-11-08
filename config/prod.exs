use Mix.Config

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
