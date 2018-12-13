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
    |> Poison.Parser.parse!()
  end

  @doc "Extracts every stop_id from the signs.json configuration"
  @spec all_stop_ids() :: [String.t()]
  def all_stop_ids do
    children_config()
    |> Enum.map(&get_stop_ids_for_sign(&1))
    |> List.flatten()
    |> Enum.reject(fn x -> x == nil end)
    |> Enum.uniq()
  end

  @spec get_stop_ids_for_sign(map()) :: [String.t()]
  defp get_stop_ids_for_sign(sign) do
    if Map.has_key?(sign, "source_config") do
      sign["source_config"]
      |> List.flatten()
      |> Enum.map(& &1["stop_id"])
    else
      [sign["gtfs_stop_id"]]
    end
  end
end
