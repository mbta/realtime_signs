import Config

config :realtime_signs, RealtimeSignsWeb.Endpoint,
  http: [port: System.get_env("MONITOR_SIGN_SCU_PORT")],
  url: [host: "localhost"],
  server: true

config :realtime_signs,
  message_log_zip_url: System.get_env("MESSAGE_LOG_ZIP_URL"),
  message_log_s3_bucket: System.get_env("MESSAGE_LOG_S3_BUCKET"),
  message_log_s3_folder: System.get_env("MESSAGE_LOG_S3_FOLDER")

scheduler_jobs =
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

config :realtime_signs, RealtimeSigns.Scheduler, jobs: scheduler_jobs

if config_env() == :prod do
  config :realtime_signs, RealtimeSignsWeb.Endpoint, secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :realtime_signs,
  http_pool_config: %{
    :default => [size: String.to_integer(System.get_env("DEFAULT_POOL_SIZE", "15"))],
    "http://#{Application.get_env(:realtime_signs, :sign_head_end_host)}" => [size: String.to_integer(System.get_env("ARINC_POOL_SIZE", "25"))],
    "http://#{Application.get_env(:realtime_signs, :sign_ui_url)}" => [size: String.to_integer(System.get_env("SIGNS_UI_POOL_SIZE", "25"))]
  }
end
