defmodule Engine.Alerts.StationConfig do
  defstruct [
    :segment_to_route_ids,
    :segment_to_stops,
    :station_neighbors,
    :station_to_stops,
    :stop_to_station
  ]

  # Identifier for a "station" as expressed in `stops.json`, really a subset of the child stops
  # at a parent station (for example "Green Line westbound stops at Park Street").
  @typep station :: String.t()

  @type t :: %__MODULE__{
          segment_to_route_ids: %{String.t() => [String.t()]},
          segment_to_stops: %{String.t() => [stop_id :: String.t()]},
          station_neighbors: %{station() => [station()]},
          station_to_stops: %{station() => [stop_id :: String.t()]},
          stop_to_station: %{(stop_id :: String.t()) => station()}
        }

  @spec load_config() :: t()
  def load_config do
    stops_data =
      :realtime_signs
      |> :code.priv_dir()
      |> Path.join("stops.json")
      |> File.read!()
      |> Jason.decode!()

    {segment_to_stops, segment_to_route_ids} =
      stops_data
      |> Enum.map(fn {segment, segment_details} ->
        stop_ids = Enum.flat_map(segment_details["stations"], & &1["stop_ids"])
        route_ids = segment_details["route_ids"]
        {{segment, stop_ids}, {segment, route_ids}}
      end)
      |> Enum.unzip()
      |> then(fn {stops_list, routes_list} ->
        {Enum.into(stops_list, %{}), Enum.into(routes_list, %{})}
      end)

    {stop_to_station, station_to_stops, station_neighbors} =
      Enum.reduce(stops_data, {%{}, %{}, %{}}, fn {_segment, stops},
                                                  {stop_to_station, station_to_stops,
                                                   station_neighbors} ->
        do_load_config(
          stops["stations"],
          stop_to_station,
          station_to_stops,
          station_neighbors,
          nil
        )
      end)

    %__MODULE__{
      stop_to_station: stop_to_station,
      station_to_stops: station_to_stops,
      station_neighbors: station_neighbors,
      segment_to_route_ids: segment_to_route_ids,
      segment_to_stops: segment_to_stops
    }
  end

  defp do_load_config([], stop_to_station, station_to_stops, station_neighbors, _) do
    {stop_to_station, station_to_stops, station_neighbors}
  end

  defp do_load_config(
         [%{"station" => station, "stop_ids" => stop_ids} | stops],
         stop_to_station,
         station_to_stops,
         station_neighbors,
         previous_station
       ) do
    station_to_stops = Map.put(station_to_stops, station, stop_ids)

    stop_to_station =
      Enum.reduce(stop_ids, stop_to_station, fn stop_id, acc -> Map.put(acc, stop_id, station) end)

    station_neighbors =
      if previous_station do
        station_neighbors
        |> Map.update(previous_station, [station], fn neighbors -> [station | neighbors] end)
        |> Map.update(station, [previous_station], fn neighbors ->
          [previous_station | neighbors]
        end)
      else
        station_neighbors
      end

    do_load_config(stops, stop_to_station, station_to_stops, station_neighbors, station)
  end
end
