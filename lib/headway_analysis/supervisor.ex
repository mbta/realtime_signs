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
    for %{"type" => "realtime"} = sign <- Signs.Utilities.SignsConfig.children_config(),
        Enum.map(sign["configs"], &{&1["headway_group"], &1["headway_direction_name"]})
        |> Enum.uniq()
        |> length() == 1 do
      Supervisor.child_spec({HeadwayAnalysis.Server, sign},
        id: {HeadwayAnalysis.Server, sign["id"]}
      )
    end
    |> Supervisor.init(strategy: :one_for_one)
  end
end
