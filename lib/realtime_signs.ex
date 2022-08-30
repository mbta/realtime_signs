defmodule RealtimeSigns do
  require Logger
  alias RealtimeSignsConfig, as: Config

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info(
      "Starting realtime_signs version #{inspect(Application.spec(:realtime_signs, :vsn))}"
    )

    runtime_config()

    children =
      [
        :hackney_pool.child_spec(:default, []),
        :hackney_pool.child_spec(:arinc_pool, []),
        {Finch,
         name: HttpClient,
         pools: %{
           :default => [size: 10],
           "http://#{Application.get_env(:realtime_signs, :sign_head_end_host)}/mbta/cgi-bin/RemoteMsgsCgi.exe" =>
             [size: 25],
           "http://#{Application.get_env(:realtime_signs, :sign_ui_url)}/messages" => [
             size: 25
           ]
         }},
        Engine.Health,
        Engine.Config,
        Engine.Predictions,
        Engine.ScheduledHeadways,
        Engine.Departures,
        Engine.Static,
        Engine.Alerts,
        MessageQueue,
        RealtimeSigns.Scheduler
      ] ++
        http_updater_children() ++
        monitor_sign_scu_uptime() ++
        [
          Signs.Supervisor
        ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    Supervisor.start_link(children, opts)
  end

  @spec runtime_config() :: :ok
  def runtime_config do
    env = System.get_env()
    :ok = Config.update_env(env, :sign_head_end_host, "SIGN_HEAD_END_HOST")
    :ok = Config.update_env(env, :sign_ui_url, "SIGN_UI_URL")
    :ok = Config.update_env(env, :sign_ui_api_key, "SIGN_UI_API_KEY", private?: true)
    :ok = Config.update_env(env, :trip_update_url, "TRIP_UPDATE_URL")
    :ok = Config.update_env(env, :vehicle_positions_url, "VEHICLE_POSITIONS_URL")
    :ok = Config.update_env(env, :s3_bucket, "SIGNS_S3_BUCKET")
    :ok = Config.update_env(env, :s3_path, "SIGNS_S3_PATH")
    :ok = Config.update_env(env, :api_v3_key, "API_V3_KEY", private?: true)
    :ok = Config.update_env(env, :api_v3_url, "API_V3_URL")

    :ok =
      Config.update_env(env, :filter_uncertain_predictions?, "FILTER_UNCERTAIN_PREDICTIONS",
        type: :boolean
      )

    :ok =
      Config.update_env(env, :number_of_http_updaters, "NUMBER_OF_HTTP_UPDATERS", type: :integer)
  end

  def monitor_sign_scu_uptime do
    if Application.get_env(:realtime_signs, RealtimeSignsWeb.Endpoint)
       |> Keyword.get(:http)
       |> Keyword.get(:port) do
      [RealtimeSignsWeb.Endpoint]
    else
      []
    end
  end

  def http_updater_children do
    num_children = Application.get_env(:realtime_signs, :number_of_http_updaters)

    for i <- 1..num_children do
      {PaEss.HttpUpdater, i}
    end
  end
end
