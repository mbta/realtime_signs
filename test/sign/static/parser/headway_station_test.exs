defmodule Static.Parser.HeadwayStationTest do
  use ExUnit.Case
  import Sign.Static.Parser.HeadwayStation
  import ExUnit.CaptureLog

  @file_path "test/data/static_test.json"

  setup do
    on_exit fn ->
      File.rm(@file_path)
    end
  end

  describe "parse_static_station_ids/1" do
    test "Correctly reads valid json file" do
      station_ids = ["station1", "station2"]
      File.write!(@file_path, Poison.encode!(station_ids))
      assert parse_static_station_ids(@file_path) == station_ids
    end

    test "warns if file cannot be read" do
      bogus_file = "made_up_dir/made_up_name"
      log = capture_log [level: :warn], fn ->
        assert parse_static_station_ids(bogus_file) == []
      end

      assert log =~ "Could not read \"#{bogus_file}\""
    end

    test "warns if file cannot be parsed" do
      File.write!(@file_path, :erlang.term_to_binary(5))
      log = capture_log [level: :warn], fn ->
        assert parse_static_station_ids(@file_path) == []
      end

      assert log =~ "Could not parse static station ids:"
    end
  end
end
