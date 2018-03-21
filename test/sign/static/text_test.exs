defmodule Sign.Static.TextTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Sign.Static.Text

  @current_time ~N[2017-07-04 09:00:00]
  @station_code "STAT"

  describe "text_for_station_code/4" do
    test "Returns empty values for nil headway ranges" do
      assert text_for_station_code(@station_code, 1, {nil, nil}, @current_time) == {"", ""}
    end

    test "Does not show message for first departure if earlier than max headway" do
      first_departure_time = Timex.shift(@current_time, minutes: 20)
      headway = {:first_departure, {10, 17}, first_departure_time}
      assert text_for_station_code(@station_code, 1, headway, @current_time) == {"", ""}
    end

    test "Shows headway message for first departure it's within headway range" do
      first_departure_time = Timex.shift(@current_time, minutes: 15)
      headway = {:first_departure, {10, 17}, first_departure_time}
      expected_message = {"Trolley to Ashmont", "Every 10 to 17 min"}
      assert text_for_station_code(@station_code, 1, headway, @current_time) == expected_message
    end

    test "Returns empty message for first departure at first departure if no headway is available" do
      first_departure_time = Timex.shift(@current_time, minutes: 15)
      headway = {:first_departure, {nil, nil}, first_departure_time}
      expected_message = {"", ""}
      assert text_for_station_code(@station_code, 1, headway, @current_time) == expected_message
    end

    test "Shows last departure message with last scheduled time" do
      last_departure_time = @current_time |> Timex.shift(hours: 12) |> Timex.to_datetime("America/New_York")
      headway = {:last_departure, last_departure_time}
      expected_message = {"Last Trolley", "Scheduled for 9:00PM"}
      assert text_for_station_code(@station_code, 1, headway, @current_time) == expected_message
    end

    test "Returns empty message if time is invalid and logs error" do
      last_departure_time = ~N[2017-07-04 05:00:00] |> Timex.to_datetime("America/New_York")
      invalid_time = %{last_departure_time | hour: 26}
      headway = {:last_departure, invalid_time}
      log = capture_log [level: :warn], fn ->
        assert text_for_station_code(@station_code, 1, headway, @current_time) == {"", ""}
      end

      assert log =~ "Could not format departure time"
    end
  end
end
