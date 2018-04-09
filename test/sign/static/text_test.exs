defmodule Sign.Static.TextTest do
  use ExUnit.Case, async: true
  import Sign.Static.Text

  @current_time ~N[2017-07-04 09:00:00]

  describe "text_for_headway/2" do
    test "Returns empty values for nil headway ranges" do
      assert text_for_headway({nil, nil}, @current_time, "Mattapan", "Trolley") == {"", ""}
    end

    test "Does not show message for first departure if earlier than max headway" do
      first_departure_time = Timex.shift(@current_time, minutes: 20)
      headway = {:first_departure, {10, 17}, first_departure_time}
      assert text_for_headway(headway, @current_time, "Mattapan", "Trolley") == {"", ""}
    end

    test "Shows headway message for first departure it's within headway range" do
      first_departure_time = Timex.shift(@current_time, minutes: 15)
      headway = {:first_departure, {10, 17}, first_departure_time}
      expected_message = {"Trolley to Mattapan", "Every 10 to 17 min"}
      assert text_for_headway(headway, @current_time, "Mattapan", "Trolley") == expected_message
    end

    test "Returns empty message for first departure at first departure if no headway is available" do
      first_departure_time = Timex.shift(@current_time, minutes: 15)
      headway = {:first_departure, {nil, nil}, first_departure_time}
      expected_message = {"", ""}
      assert text_for_headway(headway, @current_time, "Mattapan", "Trolley") == expected_message
    end

    test "Uses headsign in response" do
      assert text_for_headway({5, 5}, @current_time, "Mattapan", "Trolley") == {"Trolley to Mattapan", "Every 5 min"}
    end

    test "Uses vehicle name in response" do
      assert text_for_headway({5, 5}, @current_time, "Chelsea", "Bus") == {"Buses to Chelsea", "Every 5 min"}
    end
  end
end
