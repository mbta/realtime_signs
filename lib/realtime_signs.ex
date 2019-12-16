defmodule RealtimeSigns do
  alias RealtimeSignsConfig, as: Config

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    runtime_config()

    children =
      [
        worker(Engine.Config, []),
        worker(Engine.Predictions, []),
        worker(Engine.ScheduledHeadways, []),
        worker(Engine.Departures, []),
        worker(Engine.Bridge, []),
        worker(Engine.Static, []),
        worker(Engine.Alerts, []),
        worker(MessageQueue, [])
      ] ++
        http_updater_children() ++
        [
          supervisor(Signs.Supervisor, [])
        ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    Supervisor.start_link(children, opts)
  end

  @spec runtime_config() :: :ok
  def runtime_config do
    env = System.get_env()
    :ok = Config.update_env(env, :sign_head_end_host, "SIGN_HEAD_END_HOST", :string)
    :ok = Config.update_env(env, :sign_ui_url, "SIGN_UI_URL", :string)
    :ok = Config.update_env(env, :sign_ui_api_key, "SIGN_UI_API_KEY", :string)
    :ok = Config.update_env(env, :bridge_api_username, "BRIDGE_API_USERNAME", :string)
    :ok = Config.update_env(env, :bridge_api_password, "BRIDGE_API_PASSWORD", :string)
    :ok = Config.update_env(env, :trip_update_url, "TRIP_UPDATE_URL", :string)
    :ok = Config.update_env(env, :vehicle_positions_url, "VEHICLE_POSITIONS_URL", :string)
    :ok = Config.update_env(env, :s3_bucket, "SIGNS_S3_BUCKET", :string)
    :ok = Config.update_env(env, :s3_path, "SIGNS_S3_PATH", :string)
    :ok = Config.update_env(env, :api_v3_key, "API_V3_KEY", :string)
    :ok = Config.update_env(env, :api_v3_url, "API_V3_URL", :string)
    :ok = Config.update_env(env, :number_of_http_updaters, "NUMBER_OF_HTTP_UPDATERS", :integer)
  end

  def http_updater_children do
    num_children = Application.get_env(:realtime_signs, :number_of_http_updaters)

    for i <- 1..num_children do
      {PaEss.HttpUpdater, i}
    end
  end
end
