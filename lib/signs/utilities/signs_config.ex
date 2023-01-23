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
    children_config()
    |> Enum.filter(&match?(%{"type" => "realtime"}, &1))
    |> Enum.map(&get_stop_ids_for_sign(&1))
    |> List.flatten()
    |> Enum.reject(fn x -> x == nil end)
    |> Enum.uniq()
  end

  @spec all_bus_stop_ids() :: [String.t()]
  def all_bus_stop_ids do
    for %{"type" => "bus", "sources" => sources} <- children_config(),
        %{"stop_id" => stop_id} <- sources,
        uniq: true do
      stop_id
    end
  end

  @spec get_stop_ids_for_sign(map()) :: [String.t()]
  def get_stop_ids_for_sign(sign) do
    sign["source_config"]
    |> List.flatten()
    |> Enum.map(& &1["stop_id"])
  end
end
