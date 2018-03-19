defmodule Sign.Stations.LiveTest do
  use ExUnit.Case

  alias Sign.Stations.Live, as: L

  @stations_path Application.get_env(:realtime_signs, :stations_config)

  # Ensure that the state of the file is unchanged after the tests all exit
  setup_all do
    stations_data = File.read!(@stations_path)
    on_exit fn () ->
      File.write!(@stations_path, stations_data)
    end
  end

  test "loads the file on start" do
    {:ok, pid} = L.start_link(path: @stations_path)
    data = L.for_gtfs_id(pid, "11111")

    assert data.sign_id == "STOP"
    refute data.enabled?
    assert data.zones[0] == :center
  end

  test "reloads the file when it changes" do
    on_exit(fn -> change_all("enabled?", false) end)
    {:ok, pid} = L.start_link(path: @stations_path)
    refute L.for_gtfs_id(pid, "11111").enabled?
    :timer.sleep(1000)
    refute L.for_gtfs_id(pid, "11111").enabled?
    :timer.sleep(1000)
    change_all("enabled?", true)
    assert L.for_gtfs_id(pid, "11111").enabled?
  end

  defp change_all(key, value) do
    changed = @stations_path
    |> File.read!
    |> Poison.decode!
    |> Map.new(fn {gtfs_stop_id, station} ->
      {gtfs_stop_id, Map.put(station, key, value)}
    end)
    |> Poison.encode!

    File.write!(@stations_path, changed)
  end
end
