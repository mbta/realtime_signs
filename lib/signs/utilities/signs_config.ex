defmodule Signs.Utilities.SignsConfig do
  @moduledoc """
  Functions for loading and parsing information from the signs.json configuration file.
  """

  @doc "Pulls the entire signs.json configuration"
  @spec children_config() :: [map()]
  def children_config() do
    :realtime_signs
    |> :code.priv_dir()
    |> Path.join("signs.json")
    |> File.read!()
    |> Jason.decode!()
  end

  @doc "Extracts every train stop_id from the signs.json configuration"
  @spec all_train_stop_ids() :: [String.t()]
  def all_train_stop_ids do
    for %{"type" => "realtime"} = sign <- children_config(),
        %{"sources" => sources} <- List.wrap(sign["source_config"]),
        %{"stop_id" => stop_id} <- sources,
        uniq: true do
      stop_id
    end
  end

  @spec all_bus_stop_ids() :: [String.t()]
  def all_bus_stop_ids do
    for %{"type" => "bus"} = sign <- children_config(),
        source_list <- [sign["sources"], sign["top_sources"], sign["bottom_sources"]],
        source_list,
        %{"stop_id" => stop_id} <- source_list,
        uniq: true do
      stop_id
    end
  end

  def all_route_ids do
    config = children_config()

    train_routes =
      for %{"type" => "realtime"} = sign <- config,
          %{"sources" => sources} <- List.wrap(sign["source_config"]),
          %{"routes" => routes} <- sources,
          route <- routes do
        route
      end

    bus_routes =
      for %{"type" => "bus"} = sign <- config,
          source_list <- [sign["sources"], sign["top_sources"], sign["bottom_sources"]],
          source_list,
          %{"routes" => routes} <- source_list,
          %{"route_id" => route_id} <- routes do
        route_id
      end

    Enum.uniq(train_routes ++ bus_routes)
  end

  @spec get_stop_ids_for_sign(map()) :: [String.t()]
  def get_stop_ids_for_sign(sign) do
    sign["source_config"]
    |> List.flatten()
    |> Enum.map(& &1["stop_id"])
  end
end
