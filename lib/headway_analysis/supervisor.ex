defmodule HeadwayAnalysis.Supervisor do
  @moduledoc """
  Launches a monitoring process for each of the following signs to track headway accuracy.
  """
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init([]) do
    for %{"type" => "realtime", "source_config" => %{}} = config <-
          Signs.Utilities.SignsConfig.children_config() do
      Supervisor.child_spec({HeadwayAnalysis.Server, config},
        id: {HeadwayAnalysis.Server, config["id"]}
      )
    end
    |> Supervisor.init(strategy: :one_for_one)
  end
end
