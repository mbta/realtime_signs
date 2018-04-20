defmodule Utilities.TimeTest do
  use ExUnit.Case

  import Utilities.Time

  describe "seconds_since_midnight_to_date_time/2" do
    test "gets number of seconds since midnight" do
      assert seconds_since_midnight_to_date_time(~N[2017-02-01 07:00:00], 28800) ==
        %DateTime{year: 2017, month: 2, day: 1, zone_abbr: "EST",
                  hour: 8, minute: 0, second: 0, microsecond: {0, 0},
                  utc_offset: -18000, std_offset: 0, time_zone: "America/New_York"}
    end
  end

  test "before 3am the service date is 'yesterday'" do
    time = in_rtr_tz(~N[2017-02-01 01:23:45])

    service_date = get_service_date(time)

    assert ~D[2017-01-31] == service_date
  end

  test "gtfs_delta/2 gets the delta in seconds" do
    then = ~N[2017-01-01 12:00:00]
           |> in_rtr_tz
           |> get_seconds_since_midnight
    now = in_rtr_tz(~N[2017-01-01 13:02:00])

    assert gtfs_delta(now, then) == -3720
  end

  test "after 3am, the service date is 'today'" do
    time = in_rtr_tz(~N[2017-02-01 12:34:56])

    service_date = get_service_date(time)

    assert ~D[2017-02-01] == service_date
  end

  describe "dst_safe_shift/2" do
    test "is the same as Timex.shift normally" do
      dt = ~N[2017-08-29T12:00:00]
      assert dst_safe_shift(dt, days: 1, hours: -1) == ~N[2017-08-30T11:00:00]
    end

    test "when shifting across the fall DST boundary, returns a time in the future zone" do
      before = Timex.to_datetime(~N[2017-11-05T00:59:59], "America/New_York")
      # 1am happens twice
      actual = dst_safe_shift(before, seconds: 1)
      assert actual.hour == 1
    end

    test "when shifting across the spring DST boundary, returns a time in the future zone" do
      before = Timex.to_datetime(~N[2017-03-12T01:59:59], "America/New_York")
      # time goes from 1:59a -> 3:00a
      actual = dst_safe_shift(before, seconds: 1)
      assert actual.hour == 3
    end
  end

  describe "off_hours?/1" do
    test "Times between 1:30 and 5:15 are considered off hours" do
      assert off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 2, minute: 30, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
      assert off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 3, minute: 45, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
      assert off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 2, minute: 0, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
      assert off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 4, minute: 0, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
    end

    test "Times not between 2 and 5 are not considered off hours" do
      refute off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 5, minute: 30, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
      refute off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 13, minute: 45, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
      refute off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 21, minute: 50, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
      refute off_hours?(%DateTime{year: 2017, month: 8, day: 29, zone_abbr: "UTC", hour: 14, minute: 0, second: 0, microsecond: {0, 0}, utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"})
    end
  end
end
