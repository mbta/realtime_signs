defmodule RealtimeSigns do
  @env Mix.env()
  def env, do: @env

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Engine.Config, []),
      worker(Engine.Predictions, []),
      worker(Engine.Headways, []),
      worker(Engine.Bridge, []),
      worker(Engine.Static, []),
      worker(Engine.Alerts, []),
      worker(MessageQueue, []),
      Supervisor.child_spec({PaEss.HttpUpdater, name: :http_updater1}, id: :http_updater1),
      Supervisor.child_spec({PaEss.HttpUpdater, name: :http_updater2}, id: :http_updater2),
      Supervisor.child_spec({PaEss.HttpUpdater, name: :http_updater3}, id: :http_updater3),
      Supervisor.child_spec({PaEss.HttpUpdater, name: :http_updater4}, id: :http_updater4),
      supervisor(Signs.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    :ok = :error_logger.add_report_handler(Sentry.Logger)
    Supervisor.start_link(children, opts)
  end
end
