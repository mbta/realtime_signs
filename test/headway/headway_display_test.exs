defmodule Headway.HeadwayDisplayTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import ExUnit.CaptureLog
  import Headway.HeadwayDisplay

  describe "group_headways_for_stations/1" do
    @current_time ~N[2017-07-04 09:00:00]
    @times [
      ~N[2017-07-04 09:05:00],
      ~N[2017-07-04 08:55:00],
      ~N[2017-07-04 08:45:00],
      ~N[2017-07-04 09:20:00]
    ]

    test "adjacent times to current time are used for calculation" do
      schedules = %{
        "111" =>
          Enum.map(@times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      assert headways == %{"111" => {10, 17}}
    end

    test "filters out attributes that don't have times" do
      schedules = %{
        "111" =>
          Enum.map(@times, fn _time ->
            %{"relationships" => %{"stop" => %{"data" => %{"id" => "111"}}}, "attributes" => %{}}
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      assert headways == %{"111" => {nil, nil}}
    end

    test "Returns first departure and headway range when no departures have left yet" do
      schedules = %{
        "111" =>
          Enum.map(@times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(~N[2017-07-04 07:15:00], "America/New_York")
        )

      expected_first_departure =
        ~N[2017-07-04 08:45:00] |> Timex.to_datetime("America/New_York") |> Timex.to_unix()

      assert %{"111" => {:first_departure, {10, 12}, first_departure}} = headways
      assert Timex.to_unix(first_departure) == expected_first_departure
    end

    test "gracefully handles bad time string and logs warning" do
      schedules = %{
        "111" => [
          %{
            "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
            "attributes" => %{"departure_time" => "This is a bad time string"}
          }
        ]
      }

      log =
        capture_log([level: :warn], fn ->
          headways =
            group_headways_for_stations(
              schedules,
              ["111"],
              Timex.to_datetime(~N[2017-07-04 09:15:00], "America/New_York")
            )

          assert headways == %{"111" => {nil, nil}}
        end)

      assert log =~ "Could not parse time"
    end

    test "groups all stations by headway" do
      times2 = [
        ~N[2017-07-04 08:50:00],
        ~N[2017-07-04 09:02:00],
        ~N[2017-07-04 09:14:00]
      ]

      schedules1 = %{
        "111" =>
          Enum.map(@times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      schedules2 = %{
        "222" =>
          Enum.map(times2, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "222"}}},
              "attributes" => %{
                "arrival_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          Map.merge(schedules1, schedules2),
          ["111", "222"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      assert headways == %{"111" => {10, 17}, "222" => {12, 14}}
    end

    test "Returns :up_to for excessively-wide headway ranges without padding the upper value" do
      times = [
        ~N[2017-07-04 08:42:00],
        ~N[2017-07-04 09:02:00],
        ~N[2017-07-04 09:05:00]
      ]

      schedules = %{
        "111" =>
          Enum.map(times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      assert headways == %{"111" => {:up_to, 20}}
    end

    test "Uses a lower limit on the min headway time" do
      times = [
        ~N[2017-07-04 08:59:00],
        ~N[2017-07-04 09:00:00],
        ~N[2017-07-04 09:05:00]
      ]

      schedules = %{
        "111" =>
          Enum.map(times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      assert headways == %{"111" => {2, 7}}
    end

    test "Uses lower limit and padding on upper value" do
      times = [
        ~N[2017-07-04 08:59:00],
        ~N[2017-07-04 09:00:00],
        ~N[2017-07-04 09:01:00]
      ]

      schedules = %{
        "111" =>
          Enum.map(times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      assert headways == %{"111" => {2, 4}}
    end

    test "Pads headway when only two times are given" do
      times = [
        ~N[2017-07-04 09:01:00],
        ~N[2017-07-04 09:02:00]
      ]

      schedules = %{
        "111" =>
          Enum.map(times, fn time ->
            %{
              "relationships" => %{"stop" => %{"data" => %{"id" => "111"}}},
              "attributes" => %{
                "departure_time" =>
                  Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
              }
            }
          end)
      }

      headways =
        group_headways_for_stations(
          schedules,
          ["111"],
          Timex.to_datetime(@current_time, "America/New_York")
        )

      {:first_departure, headway, _first_time} = Map.get(headways, "111")
      assert headway == {2, 4}
    end
  end

  describe "format_headway_range/1" do
    test "returns empty string for :none headway" do
      assert format_headway_range(:none) == ""
    end

    test "formats a normal range" do
      assert format_headway_range({3, 5}) == "Every 3 to 5 min"
    end

    test "formats headways \"up to\" some number of minutes" do
      assert format_headway_range({:up_to, 20}) == "Up to every 20 min"
    end
  end

  describe "max_headway/1" do
    test "Returns max headway from range" do
      assert max_headway({1, 5}) == 5
      assert max_headway({5, 5}) == 5
      assert max_headway({5, 1}) == 5
    end

    test "Returns high end of an \"up to\" range" do
      assert max_headway({:up_to, 15}) == 15
    end

    test "Returns nil when no headway values available" do
      assert max_headway(:none) == nil
    end

    property "Returns an integer or nil" do
      check all(headway_range <- Test.Support.Generators.gen_headway_range()) do
        max_headway = max_headway(headway_range)
        assert is_integer(max_headway) or is_nil(max_headway)
      end
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

  describe "format_bottom/2" do
    test "shows how long ago the last departure was" do
      assert format_bottom(%Content.Message.Headways.Bottom{prev_departure_mins: 5, range: {1, 5}}) ==
               [{"Every 1 to 5 min", 5}, {"Departed 5 min ago", 5}]
    end

    test "when last departure is 0 minutes, does not show the last departure" do
      assert format_bottom(%Content.Message.Headways.Bottom{prev_departure_mins: 0, range: {1, 5}}) ==
               "Every 1 to 5 min"
    end
  end
end
