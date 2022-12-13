import Config

config :realtime_signs, RealtimeSignsWeb.Endpoint,
  http: [port: System.get_env("MONITOR_SIGN_SCU_PORT")],
  url: [host: "localhost"],
  server: true

config :realtime_signs,
  message_log_zip_url: System.get_env("MESSAGE_LOG_ZIP_URL"),
  message_log_s3_bucket: System.get_env("MESSAGE_LOG_S3_BUCKET"),
  message_log_s3_folder: System.get_env("MESSAGE_LOG_S3_FOLDER"),
  message_log_report_s3_folder: System.get_env("MESSAGE_LOG_REPORT_S3_FOLDER")

message_log_job =
  if System.get_env("MESSAGE_LOG_CRON_SCHEDULE") do
    [
      {
        System.get_env("MESSAGE_LOG_CRON_SCHEDULE"),
        {RealtimeSigns.MessageLogJob, :get_and_store_logs, []}
      }
    ]
  else
    []
  end

message_log_report_job =
  if System.get_env("MESSAGE_LOG_REPORT_CRON_SCHEDULE") do
    [
      {
        System.get_env("MESSAGE_LOG_REPORT_CRON_SCHEDULE"),
        {Jobs.MessageLatencyReport, :generate_message_latency_reports, []}
      }
    ]
  else
    []
  end


config :realtime_signs, RealtimeSigns.Scheduler, jobs: message_log_job ++ message_log_report_job

if config_env() == :prod do
  config :realtime_signs, RealtimeSignsWeb.Endpoint, secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :realtime_signs,
  http_pool_config: %{
    :default => [size: String.to_integer(System.get_env("DEFAULT_POOL_SIZE", "15"))],
    "http://#{Application.get_env(:realtime_signs, :sign_head_end_host)}" => [size: String.to_integer(System.get_env("ARINC_POOL_SIZE", "25"))],
    "http://#{Application.get_env(:realtime_signs, :sign_ui_url)}" => [size: String.to_integer(System.get_env("SIGNS_UI_POOL_SIZE", "25"))]
  }
end

# For maintaining backwards compatibility with opstech3
splunk_token = System.get_env("PROD_SIGNS_SPLUNK_TOKEN", "")

if config_env() == :prod and splunk_token != "" do
  config :logger, backends: [Logger.Backend.Splunk, :console]

  config :logger, :splunk,
    connector: Logger.Backend.Splunk.Output.Http,
    host: 'https://http-inputs-mbta.splunkcloud.com/services/collector/event',
    token: splunk_token,
    format: "$dateT$time [$level]$levelpad node=$node $metadata$message\n",
    metadata: [:request_id],
    max_buffer: 100
end

if System.get_env("DRY_RUN") == "true" do
  config :realtime_signs, sign_updater_mod: PaEss.Logger
end
