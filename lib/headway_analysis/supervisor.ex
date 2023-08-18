defmodule HeadwayAnalysis.Supervisor do
  @moduledoc """
  Launches a monitoring process for each of the following signs to track headway accuracy.
  """
  use Supervisor

  @sign_ids ~w(
    harvard_southbound harvard_northbound
    fields_corner_southbound fields_corner_northbound
    wollaston_southbound wollaston_northbound
    jackson_square_southbound jackson_square_northbound
    wellington_southbound wellington_northbound
    beachmont_westbound beachmont_eastbound
    aquarium_westbound aquarium_eastbound
    babcock_st_westbound babcock_st_eastbound
    prudential_westbound prudential_eastbound
    newton_centre_westbound newton_centre_eastbound
    magoun_square_westbound magoun_square_eastbound
    boylston_westbound boylston_eastbound
    lechmere_green_line_westbound lechmere_green_line_eastbound
  )

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init([]) do
    for config <- Signs.Utilities.SignsConfig.children_config(), config["id"] in @sign_ids do
      Supervisor.child_spec({HeadwayAnalysis.Server, config},
        id: {HeadwayAnalysis.Server, config["id"]}
      )
    end
    |> Supervisor.init(strategy: :one_for_one)
  end
end
