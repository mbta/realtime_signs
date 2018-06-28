use Mix.Config

config :sentry,
  dsn: System.get_env("SENTRY_DSN") || "",
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!,
  tags: %{
    env: "production"
  },
  included_environments: [:prod]

config :logger,
  backends: [{Logger.Backend.Splunk, :splunk}, :console]

config :logger, :splunk,
  connector: Logger.Backend.Splunk.Output.Http,
  host: 'https://http-inputs-mbta.splunkcloud.com/services/collector/event',
  token: {:system, "PROD_SIGNS_SPLUNK_TOKEN"},
  format: "$dateT$time [$level]$levelpad node=$node $metadata$message\n",
  metadata: [:request_id]

config :realtime_signs,
  external_config_getter: ExternalConfig.S3,
  sign_updater_mod: MessageQueue
