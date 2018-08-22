defmodule Content.Audio.UtilitiesTest do
  use ExUnit.Case, async: true

  import PaEss.Utilities

  test "valid_range?" do
    assert valid_range?(10, :english)
    assert valid_range?(10, :spanish)
    refute valid_range?(100, :english)
    refute valid_range?(100, :spanish)
  end

  test "number_var/2" do
    assert number_var(10, :english) == "5510"
    assert number_var(10, :spanish) == "37010"
  end

  test "time_var/1" do
    assert time_var(10) == "9110"
  end

  test "countdown_minutes_var/1" do
    assert countdown_minutes_var(10) == "5010"
  end

  test "take_message_id/1" do
    assert take_message_id(["1", "2", "3"]) == "105"
  end

  test "destination_var/1" do
    assert destination_var(:ashmont) == "4016"
    assert destination_var(:mattapan) == "4100"
    assert destination_var(:bowdoin) == "4055"
    assert destination_var(:wonderland) == "4044"
    assert destination_var(:forest_hills) == "4043"
    assert destination_var(:oak_grove) == "4022"
    assert destination_var(:braintree) == "4021"
    assert destination_var(:alewife) == "4000"
  end

  test "headsign_to_terminal_station/1" do
    assert headsign_to_terminal_station("Ashmont") == {:ok, :ashmont}
    assert headsign_to_terminal_station("Mattapan") == {:ok, :mattapan}
    assert headsign_to_terminal_station("Bowdoin") == {:ok, :bowdoin}
    assert headsign_to_terminal_station("Wonderland") == {:ok, :wonderland}
    assert headsign_to_terminal_station("Frst Hills") == {:ok, :forest_hills}
    assert headsign_to_terminal_station("Oak Grove") == {:ok, :oak_grove}
    assert headsign_to_terminal_station("Braintree") == {:ok, :braintree}
    assert headsign_to_terminal_station("Alewife") == {:ok, :alewife}
    assert headsign_to_terminal_station("Unknown") == {:error, :unknown}
  end
end
