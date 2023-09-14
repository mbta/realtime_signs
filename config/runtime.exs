import Config

config :realtime_signs, RealtimeSignsWeb.Endpoint,
  http: [port: System.get_env("MONITOR_SIGN_SCU_PORT", "4000")],
  url: [host: "localhost"],
  server: true

if config_env() != :test do
  config :realtime_signs,
    sign_ui_url: System.get_env("SIGN_UI_URL"),
    sign_ui_api_key: System.get_env("SIGN_UI_API_KEY"),
    trip_update_url: System.get_env("TRIP_UPDATE_URL", "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json"),
    vehicle_positions_url: System.get_env("VEHICLE_POSITIONS_URL", "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/VehiclePositions_enhanced.json"),
    s3_bucket: System.get_env("SIGNS_S3_BUCKET"),
    s3_path: System.get_env("SIGNS_S3_PATH"),
    api_v3_url: System.get_env("API_V3_URL"),
    api_v3_key: System.get_env("API_V3_KEY"),
    chelsea_bridge_url: System.get_env("CHELSEA_BRIDGE_URL"),
    chelsea_bridge_auth: System.get_env("CHELSEA_BRIDGE_AUTH"),
    filter_uncertain_predictions?: System.get_env("FILTER_UNCERTAIN_PREDICTIONS", "false") == "true",
    number_of_http_updaters: System.get_env("NUMBER_OF_HTTP_UPDATERS", "4") |> String.to_integer(),
    message_log_zip_url: System.get_env("MESSAGE_LOG_ZIP_URL"),
    message_log_s3_bucket: System.get_env("MESSAGE_LOG_S3_BUCKET"),
    message_log_s3_folder: System.get_env("MESSAGE_LOG_S3_FOLDER"),
    message_log_report_s3_folder: System.get_env("MESSAGE_LOG_REPORT_S3_FOLDER"),
    monitoring_api_key: System.get_env("MONITORING_API_KEY"),
    active_headend_path: System.get_env("ACTIVE_HEADEND_S3_PATH", "/headend.json"),
end

if config_env() == :dev do
  config :realtime_signs,
    sign_config_file: System.get_env("SIGN_CONFIG_FILE")
end

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
end

# For maintaining backwards compatibility with opstech3
splunk_token = System.get_env("PROD_SIGNS_SPLUNK_TOKEN", "")

if config_env() == :prod and splunk_token != "" do
  config :logger, backends: [Logger.Backend.Splunk, :console]

  config :logger, :splunk,
    connector: Logger.Backend.Splunk.Output.Http,
    host: 'https://http-inputs-mbta.splunkcloud.com/services/collector/event',
    token: splunk_token,
    format: "$dateT$time [$level] node=$node $metadata$message\n",
    metadata: [:request_id],
    max_buffer: 100
end
