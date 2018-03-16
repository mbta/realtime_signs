defmodule Sign.Stations.Live do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{path: opts[:path]}, opts)
  end

  def init(%{path: path}) do
    try do
      stations = parse_file!(path)
      last_updated_at = File.stat!(path).mtime
      {:ok, %{stations: stations, last_updated_at: last_updated_at, path: path}}
    rescue
      e ->
        Logger.error("#{__MODULE__} Load Error: #{Exception.format(:throw, e)}")
        :ignore
    end
  end

  def for_gtfs_id(pid \\ __MODULE__, gtfs_stop_id) do
    GenServer.call(pid, {:for_gtfs_id, gtfs_stop_id})
  end

  def get_stations(pid \\ __MODULE__, stop_ids) do
    GenServer.call(pid, {:get_stations, stop_ids})
  end

  def state(pid \\ __MODULE__) do
    GenServer.call(pid, :state)
  end

  def handle_call({:get_stations, stop_ids}, _from, state) do
    {:reply, Enum.map(stop_ids, &Map.get(state.stations, &1)), state}
  end
  def handle_call({:for_gtfs_id, gtfs_stop_id}, _from, state) do
    mtime = File.stat!(state.path).mtime
    state = if mtime > state.last_updated_at do
      %{state | stations: parse_file!(state.path), last_updated_at: mtime}
    else
      state
    end
    {:reply, state.stations[gtfs_stop_id], state}
  end

  defp parse_file!(path) do
    path
    |> File.read!
    |> Poison.decode!
    |> Enum.map(&parse_station/1)
    |> Enum.into(%{})
  end

  defp parse_station({gtfs_stop_id, station}) do
    {gtfs_stop_id, %Sign.Station{
      enabled?: station["enabled?"],
      id: gtfs_stop_id,
      sign_id: station["sign_id"],
      display_type: parse_display_type(station["display_type"]),
      route_id: station["route_id"],
      zones: parse_zones(station["zones"])
    }}
  end

  defp parse_display_type("separate"), do: :separate
  defp parse_display_type("combined"), do: :combined
  defp parse_display_type(["one_line", line]) do
    {:one_line, line}
  end

  defp parse_zones(zones) do
    Map.new(zones, fn {direction_id, zone} ->
      {String.to_integer(direction_id), parse_zone(zone)}
    end)
  end

  defp parse_zone("mezzanine"), do: :mezzanine
  defp parse_zone("center"), do: :center
  defp parse_zone("northbound"), do: :northbound
  defp parse_zone("southbound"), do: :southbound
  defp parse_zone("eastbound"), do: :eastbound
  defp parse_zone("westbound"), do: :westbound
end
