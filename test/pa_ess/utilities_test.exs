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
    assert number_var(61, :english) == nil
    assert number_var(21, :spanish) == nil
  end

  test "time_var/1" do
    assert time_var(10) == "9110"
  end

  test "countdown_minutes_var/1" do
    assert countdown_minutes_var(10) == "5010"
  end

  test "take_message_id/1" do
    assert take_message_id(["1", "2", "3"]) == "105"
    assert take_message_id(List.duplicate("1", 31)) == "220"
    assert take_message_id(List.duplicate("1", 40)) == "230"
  end

  test "headsign_to_destination/1" do
    assert headsign_to_destination("Alewife") == :alewife
    assert headsign_to_destination("Ashmont") == :ashmont
    assert headsign_to_destination("Boston College") == :boston_college
    assert headsign_to_destination("Bowdoin") == :bowdoin
    assert headsign_to_destination("Braintree") == :braintree
    assert headsign_to_destination("Cleveland Circle") == :cleveland_circle
    assert headsign_to_destination("Forest Hills") == :forest_hills
    assert headsign_to_destination("Government Center") == :government_center
    assert headsign_to_destination("Heath Street") == :heath_street
    assert headsign_to_destination("Lechmere") == :lechmere
    assert headsign_to_destination("Union Square") == :union_square
    assert headsign_to_destination("Mattapan") == :mattapan
    assert headsign_to_destination("North Station") == :north_station
    assert headsign_to_destination("Oak Grove") == :oak_grove
    assert headsign_to_destination("Park Street") == :park_street
    assert headsign_to_destination("Reservoir") == :reservoir
    assert headsign_to_destination("Riverside") == :riverside
    assert headsign_to_destination("Wonderland") == :wonderland
    assert headsign_to_destination("Medford/Tufts") == :medford_tufts
  end

  test "destination_to_sign_string/1" do
    assert destination_to_sign_string(:forest_hills) == "Frst Hills"
    assert destination_to_sign_string(:southbound) == "Southbound"
  end

  test "destination_to_ad_hoc_string/1" do
    assert destination_to_ad_hoc_string(:heath_street) == "Heath Street"
    assert destination_to_ad_hoc_string(:southbound) == "Southbound"
  end

  describe "replace_abbreviations/1" do
    test "replaces multiple times, including binary start and end" do
      assert replace_abbreviations("RL and RL and OL") == "Red Line and Red Line and Orange Line"
    end

    test "does not replace when touching other letters" do
      assert replace_abbreviations("BLAM!") == "BLAM!"
    end

    test "replaces when next to punctuation" do
      assert replace_abbreviations("OL, OK") == "Orange Line, OK"
    end

    test "case insenstive replacement of 'SVC' with 'Service'" do
      assert replace_abbreviations("SvC, OK") == "Service, OK"
    end
  end

  test "paginate_text" do
    assert [{"Attention passengers:", "the next Braintree train", 3}, {"is now arriving", "", 3}] =
             paginate_text("Attention passengers: the next Braintree train is now arriving", 24)

    assert [{"too-long", "word", 3}] = paginate_text(" too-long   word ", 5)
    assert [{"fits", "", 3}] = paginate_text("fits", 24)
    assert [] = paginate_text("")
  end

  test "pad_takes" do
    assert ["1", "21000", "2", "21000", "3"] = pad_takes(["1", "2", "3"])
    assert ["1", "21012", "21000", "2"] = pad_takes(["1", "21012", "2"])
    assert ["1", "21000", "2", "21014"] = pad_takes(["1", "2", "21014"])
  end
end
