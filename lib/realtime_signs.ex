defmodule RealtimeSigns do

  @env Mix.env
  def env, do: @env

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Engine.Predictions, []),
      worker(Engine.Schedules, []),
      worker(Engine.Static, []),
      worker(PaEssUpdater, []),
      supervisor(Signs.Supervisor, []),
      worker(Signs.Starter, [], restart: :transient)
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    :ok = :error_logger.add_report_handler(Sentry.Logger)
    Supervisor.start_link(children, opts)
  end
end
