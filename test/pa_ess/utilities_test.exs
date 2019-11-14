defmodule Content.Audio.UtilitiesTest do
  use ExUnit.Case, async: true

  import PaEss.Utilities

  test "valid_range?" do
    assert valid_range?(10, :english)
    assert valid_range?(10, :spanish)
    refute valid_range?(100, :english)
    refute valid_range?(100, :spanish)
  end

  test "valid_destination?" do
    assert valid_destination?(:chelsea, :spanish)
    assert valid_destination?(:south_station, :english)
    refute valid_destination?(:cleveland_circle, :spanish)
  end

  test "number_var/2" do
    assert number_var(10, :english) == "5510"
    assert number_var(10, :spanish) == "37010"
    assert number_var(61, :english) == nil
    assert number_var(21, :spanish) == nil
  end

  test "time_var/1" do
    assert time_var(10) == "9110"
  end

  test "countdown_minutes_var/1" do
    assert countdown_minutes_var(10) == "5010"
  end

  test "take_message/2" do
    assert take_message(["1", "2", "3"], :audio_visual) ==
             {:canned, {"107", ["1", "21000", "2", "21000", "3"], :audio_visual}}
  end

  test "take_message_id/1" do
    assert take_message_id(["1", "2", "3"]) == "105"
  end

  test "destination_var/1" do
    assert destination_var(:alewife) == {:ok, "4000"}
    assert destination_var(:ashmont) == {:ok, "4016"}
    assert destination_var(:boston_college) == {:ok, "4202"}
    assert destination_var(:bowdoin) == {:ok, "4055"}
    assert destination_var(:braintree) == {:ok, "4021"}
    assert destination_var(:cleveland_circle) == {:ok, "4203"}
    assert destination_var(:forest_hills) == {:ok, "4043"}
    assert destination_var(:government_center) == {:ok, "4061"}
    assert destination_var(:heath_street) == {:ok, "4204"}
    assert destination_var(:kenmore) == {:ok, "4070"}
    assert destination_var(:lechmere) == {:ok, "4056"}
    assert destination_var(:mattapan) == {:ok, "4100"}
    assert destination_var(:north_station) == {:ok, "4027"}
    assert destination_var(:oak_grove) == {:ok, "4022"}
    assert destination_var(:park_street) == {:ok, "4007"}
    assert destination_var(:reservoir) == {:ok, "4076"}
    assert destination_var(:riverside) == {:ok, "4084"}
    assert destination_var(:wonderland) == {:ok, "4044"}
  end

  test "headsign_to_destination/1" do
    assert headsign_to_destination("Alewife") == {:ok, :alewife}
    assert headsign_to_destination("Ashmont") == {:ok, :ashmont}
    assert headsign_to_destination("Boston Col") == {:ok, :boston_college}
    assert headsign_to_destination("Bowdoin") == {:ok, :bowdoin}
    assert headsign_to_destination("Braintree") == {:ok, :braintree}
    assert headsign_to_destination("Clvlnd Cir") == {:ok, :cleveland_circle}
    assert headsign_to_destination("Frst Hills") == {:ok, :forest_hills}
    assert headsign_to_destination("Govt Ctr") == {:ok, :government_center}
    assert headsign_to_destination("Heath St") == {:ok, :heath_street}
    assert headsign_to_destination("Lechmere") == {:ok, :lechmere}
    assert headsign_to_destination("Mattapan") == {:ok, :mattapan}
    assert headsign_to_destination("North Sta") == {:ok, :north_station}
    assert headsign_to_destination("Oak Grove") == {:ok, :oak_grove}
    assert headsign_to_destination("Park St") == {:ok, :park_street}
    assert headsign_to_destination("Reservoir") == {:ok, :reservoir}
    assert headsign_to_destination("Riverside") == {:ok, :riverside}
    assert headsign_to_destination("Wonderland") == {:ok, :wonderland}
    assert headsign_to_destination("Unknown") == {:error, :unknown}
  end
end
