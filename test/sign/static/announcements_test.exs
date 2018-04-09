defmodule Sign.Static.AnnoucementsTest do
  use ExUnit.Case, async: true
  import Sign.Static.Announcements
  alias Sign.Platforms
  @current_time ~N[2017-07-04 09:00:00]

  describe "from_schedule_headways/3" do
    test "generates announcements for english and spanish" do
      headways = %{"70268" => {12, 15}}
      announcements = from_schedule_headways(headways, @current_time, {"Lowered", nil})
      assert Enum.count(announcements) == 4 # English and Spanish for both platforms
    end

    test "generates bridge is raised announcement with duration when bridge is raised" do
      headways = %{"70268" => {12, 15}}
      durations = [180, 480, 900, 1140 , 1440, 1940]
      expected_english_duration = [5505, 5510, 5515, 5520, 5525, 5530]
      expected_spanish_duration = [37005, 37010, 37015, 37020, 37025, 37030]
      for {duration, idx} <- Enum.with_index(durations) do
        announcements = from_schedule_headways(headways, @current_time, {"Raised", duration})
        [english, spanish] = announcements
        assert Enum.count(announcements) == 2
        assert Enum.all?(announcements, &match?(%Platforms{nb: true, sb: true}, &1.platforms))
        assert english.mid == 135
        assert spanish.mid == 152
        assert english.variables == [Enum.at(expected_english_duration, idx)]
        assert spanish.variables == [Enum.at(expected_spanish_duration, idx)]
      end
    end

    test "creates \"soon\" announcement when duration is unknown" do
      headways = %{"70268" => {12, 15}}
      [english, spanish] = from_schedule_headways(headways, @current_time, {"Raised", nil})
      assert english.mid == 136
      assert english.variables == []
      assert spanish.mid == 153
      assert spanish.variables == []
    end

    test "does not create headway announcement if it is too early" do
      first_departure_time = Timex.shift(@current_time, minutes: 20)
      headways = %{"70268" => {:first_departure, {12, 15}, first_departure_time}}
      announcements = from_schedule_headways(headways, @current_time, {"Lowered", nil})
      assert announcements == []
    end

    test "does create headway announcement if first departure is within headway range" do
      first_departure_time = Timex.shift(@current_time, minutes: 2)
      headways = %{"70268" => {:first_departure, {12, 15}, first_departure_time}}
      announcements = from_schedule_headways(headways, @current_time, {"Lowered", nil})
      refute Enum.empty?(announcements)
      english_sb = List.first(announcements)
      spanish_sb = Enum.at(announcements, 2)
      assert english_sb.mid == 133
      assert spanish_sb.mid == 150
    end

    test "assert headway variables are in correct order" do
      headways = %{"70268" => {10, 4}}
      announcements = from_schedule_headways(headways, @current_time, {"Lowered", nil})
      refute Enum.empty?(announcements)
      english_sb = List.first(announcements)
      assert english_sb.variables == [5504, 5510]
    end

    test "Does not send announcements after last scheduled trip of the day" do
      headways = %{"70268" => {nil, nil}}
      announcements = from_schedule_headways(headways, @current_time, {"Lowered", nil})
      assert Enum.empty?(announcements)
    end
  end
end
