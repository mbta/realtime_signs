defmodule RealtimeSigns do
  @env Mix.env()
  def env, do: @env

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children =
      [
        worker(Engine.Config, []),
        worker(Engine.Predictions, []),
        worker(Engine.ObservedHeadways, []),
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
    :ok = :error_logger.add_report_handler(Sentry.Logger)
    Supervisor.start_link(children, opts)
  end

  def http_updater_children do
    num_children = Application.get_env(:realtime_signs, :number_of_http_updaters)

    for i <- 1..num_children do
      {PaEss.HttpUpdater, i}
    end
  end
end
