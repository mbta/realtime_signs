defmodule Engine.Alerts.StationConfig do
  defstruct [:stop_to_station, :station_to_stops, :station_neighbors]

  def load_config do
    stops_data =
      :realtime_signs
      |> :code.priv_dir()
      |> Path.join("stops.json")
      |> File.read!()
      |> Jason.decode!()

    {stop_to_station, station_to_stops, station_neighbors} =
      Enum.reduce(stops_data, {%{}, %{}, %{}}, fn {_segment, stops},
                                                  {stop_to_station, station_to_stops,
                                                   station_neighbors} ->
        do_load_config(stops, stop_to_station, station_to_stops, station_neighbors, nil)
      end)

    %__MODULE__{
      stop_to_station: stop_to_station,
      station_to_stops: station_to_stops,
      station_neighbors: station_neighbors
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
