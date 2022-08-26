use Mix.Config

config :logger,
  backends: [{Logger.Backend.Splunk, :splunk}, :console],
  utc_log: true

config :logger, :splunk,
  connector: Logger.Backend.Splunk.Output.Http,
  host: 'https://http-inputs-mbta.splunkcloud.com/services/collector/event',
  token: {:system, "SIGNS_SPLUNK_TOKEN"},
  format: "$dateT$time [$level]$levelpad $metadata$message\n",
  metadata: [:request_id]
