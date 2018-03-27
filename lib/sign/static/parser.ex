defmodule Sign.Static.Parser do
  require Logger
  alias Sign.Station

  @spec parse_static_station_ids(String.t) :: [Station.t]
  def parse_static_station_ids(filename) do
    case File.read(filename) do
      {:ok, binary} ->
        parse_json_binary(binary)
      {:error, reason} ->
        Logger.warn("Could not read #{inspect filename}: #{inspect reason}")
        []
    end
  end

  defp parse_json_binary(binary) do
    case Poison.decode(binary) do
      {:ok, station_ids} ->
        station_ids
      {:error, reason, _} ->
        Logger.warn("Could not parse static station ids: #{inspect reason}")
        []
    end
  end
end
