defmodule RealtimeSigns do
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info(
      "Starting realtime_signs version #{inspect(Application.spec(:realtime_signs, :vsn))}"
    )

    log_runtime_config()

    scu_updater_children =
      Signs.Utilities.SignsConfig.all_scu_ids()
      |> Enum.flat_map(fn id ->
        [
          Supervisor.child_spec({PaEss.ScuQueue, id}, id: {PaEss.ScuQueue, id}),
          Supervisor.child_spec({PaEss.ScuUpdater, id}, id: {PaEss.ScuUpdater, id})
        ]
      end)

    children =
      [
        :hackney_pool.child_spec(:default, []),
        :hackney_pool.child_spec(:arinc_pool, []),
        {Task.Supervisor, name: PaEss.TaskSupervisor},
        Engine.Health,
        Engine.Config,
        Engine.Locations,
        Engine.LastTrip,
        Engine.Predictions,
        Engine.ScheduledHeadways,
        Engine.Static,
        Engine.Alerts,
        Engine.BusPredictions,
        Engine.ChelseaBridge,
        Engine.Routes,
        Engine.PaMessages,
        Engine.BusStops,
        MessageQueue,
        RealtimeSigns.Scheduler,
        RealtimeSignsWeb.Endpoint,
        HeadwayAnalysis.Supervisor
      ] ++
        http_updater_children() ++
        scu_updater_children ++
        [
          Signs.Supervisor
        ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  @spec log_runtime_config() :: :ok
  def log_runtime_config do
    Logger.info(
      "environment_variable SIGN_HEAD_END_HOST=#{inspect(Application.get_env(:realtime_signs, :sign_head_end_host))}"
    )

    Logger.info(
      "environment_variable NUMBER_OF_HTTP_UPDATERS=#{inspect(Application.get_env(:realtime_signs, :number_of_http_updaters))}"
    )

    Logger.info(
      "environment_variable API_V3_URL=#{inspect(Application.get_env(:realtime_signs, :api_v3_url))}"
    )

    Logger.info(
      "environment_variable TRIP_UPDATE_URL=#{inspect(Application.get_env(:realtime_signs, :trip_update_url))}"
    )

    Logger.info(
      "environment_variable VEHICLE_POSITIONS_URL=#{inspect(Application.get_env(:realtime_signs, :vehicle_positions_url))}"
    )
  end

  def http_updater_children do
    num_children = Application.get_env(:realtime_signs, :number_of_http_updaters)

    for i <- 1..num_children do
      Supervisor.child_spec({PaEss.HttpUpdater, i}, id: {PaEss.HttpUpdater, i})
    end
  end

  def location_engine, do: Application.fetch_env!(:realtime_signs, :location_engine)
  def config_engine, do: Application.fetch_env!(:realtime_signs, :config_engine)
  def headway_engine, do: Application.fetch_env!(:realtime_signs, :headway_engine)
  def prediction_engine, do: Application.fetch_env!(:realtime_signs, :prediction_engine)
  def alert_engine, do: Application.fetch_env!(:realtime_signs, :alert_engine)
  def last_trip_engine, do: Application.fetch_env!(:realtime_signs, :last_trip_engine)
  def bridge_engine, do: Application.fetch_env!(:realtime_signs, :bridge_engine)
  def route_engine, do: Application.fetch_env!(:realtime_signs, :route_engine)
  def bus_prediction_engine, do: Application.fetch_env!(:realtime_signs, :bus_prediction_engine)
  def bus_stop_engine, do: Application.fetch_env!(:realtime_signs, :bus_stop_engine)
  def sign_updater, do: Application.fetch_env!(:realtime_signs, :sign_updater)
end
