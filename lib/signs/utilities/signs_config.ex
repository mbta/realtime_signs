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
    |> Enum.flat_map(&(&1[:source_config] || []))
    |> Enum.map(& &1[:stop_id])
    |> Enum.uniq()
  end
end
