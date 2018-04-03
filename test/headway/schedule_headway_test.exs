defmodule Headway.ScheduleHeadwayTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Headway.ScheduleHeadway

  describe "build_request/1" do
    test "builds request with comma separated station ids" do
      assert build_request(["7022", "1123"]) == "https://api-v3.mbta.com/schedules?filter[stop]=7022,1123"
      assert build_request(["7022"]) == "https://api-v3.mbta.com/schedules?filter[stop]=7022"
    end
  end

  describe "group_headways_for_stations/1" do
    @current_time ~N[2017-07-04 09:00:00]
    @times [
      ~N[2017-07-04 09:05:00],
      ~N[2017-07-04 08:55:00],
      ~N[2017-07-04 08:45:00],
      ~N[2017-07-04 09:20:00]
    ]

    test "adjacent times to current time are used for calculation" do
      schedules = Enum.map(@times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)
      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(@current_time, "America/New_York"))
      assert headways == %{"111" => {10, 17}}
    end

    test "filters out attributes that don't have times" do
      schedules = Enum.map(@times, fn _time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{}}
      end)
      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(@current_time, "America/New_York"))
      assert headways == %{"111" => {nil, nil}}
    end

    test "Returns first departure and headway range when no departures have left yet" do
      schedules = Enum.map(@times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)
      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(~N[2017-07-04 07:15:00], "America/New_York"))
      expected_first_departure = ~N[2017-07-04 08:45:00] |> Timex.to_datetime("America/New_York") |> Timex.to_unix

      assert %{"111" => {:first_departure, {10, 12}, first_departure}} = headways
      assert Timex.to_unix(first_departure) == expected_first_departure
    end

    test "gracefully handles bad time string and logs warning" do
      schedules = [%{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
         "attributes" => %{"departure_time" => "This is a bad time string"}}]
      log = capture_log [level: :warn], fn ->
        headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(~N[2017-07-04 09:15:00], "America/New_York"))
        assert headways == %{"111" => {nil, nil}}
      end

      assert log =~ "Could not parse time"
    end

    test "groups all stations by headway" do
      times2 = [
        ~N[2017-07-04 08:50:00],
        ~N[2017-07-04 09:02:00],
        ~N[2017-07-04 09:14:00]
      ]

      schedules1 = Enum.map(@times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)

      schedules2 = Enum.map(times2, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "222"}}},
          "attributes" => %{"arrival_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)

      headways = group_headways_for_stations(schedules1 ++ schedules2, ["111", "222"], Timex.to_datetime(@current_time, "America/New_York"))
      assert headways == %{"111" => {10, 17}, "222" => {12, 14}}
    end

    test "Adds two minutes to the max headway time" do
      times = [
        ~N[2017-07-04 08:42:00],
        ~N[2017-07-04 09:02:00],
        ~N[2017-07-04 09:05:00]
      ]

      schedules = Enum.map(times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)

      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(@current_time, "America/New_York"))
      assert headways == %{"111" => {5, 22}}
    end

    test "Uses a lower limit on the min headway time" do
      times = [
        ~N[2017-07-04 08:58:00],
        ~N[2017-07-04 09:02:00],
        ~N[2017-07-04 09:10:00]
      ]

      schedules = Enum.map(times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)

      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(@current_time, "America/New_York"))
      assert headways == %{"111" => {5, 10}}
    end

    test "Uses lower limit and padding on upper value" do
      times = [
        ~N[2017-07-04 08:59:00],
        ~N[2017-07-04 09:01:00],
        ~N[2017-07-04 09:02:00]
      ]

      schedules = Enum.map(times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)

      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(@current_time, "America/New_York"))
      assert headways == %{"111" => {5, 7}}
    end

    test "Pads headway when only two times are given" do
      times = [
        ~N[2017-07-04 09:01:00],
        ~N[2017-07-04 09:02:00],
      ]

      schedules = Enum.map(times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)

      headways = group_headways_for_stations(schedules, ["111"], Timex.to_datetime(@current_time, "America/New_York"))
      {:first_departure, headway, _first_time} = Map.get(headways, "111")
      assert headway == {5, nil}
    end
  end

  describe "format_headway_range/1" do
    test "returns nil string for nil headway" do
      assert format_headway_range({nil, nil}) == ""
    end

    test "formats lower headway time first" do
      assert format_headway_range({5, 3}) == "Every 3 to 5 min"
      assert format_headway_range({3, 5}) == "Every 3 to 5 min"
    end

    test "formats single headway if both are the same" do
      assert format_headway_range({5, 5}) == "Every 5 min"
    end
  end

  describe "max_headway/1" do
    test "Returns max headway from range" do
      assert max_headway({1,5}) == 5
      assert max_headway({5,5}) == 5
      assert max_headway({5,1}) == 5
    end

    test "Returns max headway when nil value is included" do
      assert max_headway({5,nil}) == 5
      assert max_headway({nil, 5}) == 5
    end

    test "Returns nil when no headway values available" do
      assert max_headway({nil,nil}) == nil
    end
  end

  describe "show_first_departure?/3" do
    test "Does not show first departure if it is earlier than the max headway" do
      first_departure = ~N[2017-07-04 09:05:00]
      current_time = ~N[2017-07-04 08:35:00]

      refute show_first_departure?(first_departure, current_time, 10)
    end

    test "shows first departure if within max headway window" do
      first_departure = ~N[2017-07-04 09:05:00]
      current_time = ~N[2017-07-04 09:10:00]

      assert show_first_departure?(first_departure, current_time, 10)
    end
  end
end
