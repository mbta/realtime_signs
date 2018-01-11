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

config :logger, :splunk,
  connector: Logger.Backend.Splunk.Output.SslKeepOpen,
  host: 'mbta.splunkcloud.com',
  port: 9997,
  token: {:system, "SPLUNK_TOKEN"},
  format: "$dateT$time [$level]$levelpad node=$node $metadata$message\n",
  metadata: [:request_id]
