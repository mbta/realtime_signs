defmodule Sign.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Sign.State, [[name: Sign.State]]),
      worker(Sign.Stations.Live, [[name: Sign.Stations.Live, path: Application.get_env(:realtime_signs, :stations_config)]]),
      worker(Sign.Updater, [[name: Sign.Updater]])
    ]

    supervise(children, strategy: :one_for_all)
  end
end
