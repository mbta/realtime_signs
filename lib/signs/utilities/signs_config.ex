defmodule Signs.Utilities.SignsConfig do
  @moduledoc """
  Functions for loading and parsing information from the signs.json configuration file.
  """

  @doc "Pulls the entire signs.json configuration"
  @spec children_config() :: [map()]
  def children_config() do
    # This override allows testing the in-progress bus work, and is off by default.
    # It should be removed once the work is complete.
    test_bus_mode = Application.get_env(:realtime_signs, :test_bus_mode)

    :realtime_signs
    |> :code.priv_dir()
    |> Path.join(if test_bus_mode, do: "bus-signs.json", else: "signs.json")
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
    for %{"type" => "bus"} = sign <- children_config(),
        source_list <- [sign["sources"], sign["top_sources"], sign["bottom_sources"]],
        source_list,
        %{"stop_id" => stop_id} <- source_list,
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
