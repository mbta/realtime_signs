use Mix.Config

config :realtime_signs, RealtimeSignsWeb.Endpoint,
  url: [host: "localhost"],
  server: true

config :logger,
  backends: [:console]

config :logger, :splunk,
  connector: Logger.Backend.Splunk.Output.Http,
  host: 'https://http-inputs-mbta.splunkcloud.com/services/collector/event',
  token: {:system, "SIGNS_SPLUNK_TOKEN"},
  format: "$dateT$time [$level]$levelpad $metadata$message\n",
  metadata: [:request_id]
