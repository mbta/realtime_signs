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
    assert headsign_to_destination("Boston College") == {:ok, :boston_college}
    assert headsign_to_destination("Bowdoin") == {:ok, :bowdoin}
    assert headsign_to_destination("Braintree") == {:ok, :braintree}
    assert headsign_to_destination("Cleveland Circle") == {:ok, :cleveland_circle}
    assert headsign_to_destination("Forest Hills") == {:ok, :forest_hills}
    assert headsign_to_destination("Government Center") == {:ok, :government_center}
    assert headsign_to_destination("Heath Street") == {:ok, :heath_street}
    assert headsign_to_destination("Lechmere") == {:ok, :lechmere}
    assert headsign_to_destination("Mattapan") == {:ok, :mattapan}
    assert headsign_to_destination("North Station") == {:ok, :north_station}
    assert headsign_to_destination("Oak Grove") == {:ok, :oak_grove}
    assert headsign_to_destination("Park Street") == {:ok, :park_street}
    assert headsign_to_destination("Reservoir") == {:ok, :reservoir}
    assert headsign_to_destination("Riverside") == {:ok, :riverside}
    assert headsign_to_destination("Wonderland") == {:ok, :wonderland}
    assert headsign_to_destination("Unknown") == {:error, :unknown}
  end

  test "destination_to_sign_string/1" do
    assert destination_to_sign_string(:forest_hills) == "Frst Hills"
    assert destination_to_sign_string(:southbound) == "Southbound"
  end

  test "destination_to_ad_hoc_string/1" do
    assert destination_to_ad_hoc_string(:heath_street) == {:ok, "Heath Street"}
    assert destination_to_ad_hoc_string(:southbound) == {:ok, "Southbound"}
  end

  describe "ad_hoc_trip_description/2" do
    test "handles locations as destinations" do
      assert ad_hoc_trip_description(:forest_hills) == {:ok, "train to Forest Hills"}

      assert ad_hoc_trip_description(:forest_hills, "Orange") ==
               {:ok, "Orange Line train to Forest Hills"}

      assert ad_hoc_trip_description(:forest_hills, "An-Unexpected-Route") ==
               {:ok, "train to Forest Hills"}

      assert ad_hoc_trip_description(:unknown) == {:error, :unknown}
      assert ad_hoc_trip_description(:unknown, "Green-D") == {:error, :unknown}
    end

    test "handles cardinal directions as destinations" do
      assert ad_hoc_trip_description(:northbound) == {:ok, "Northbound train"}

      assert ad_hoc_trip_description(:northbound, "Orange") ==
               {:ok, "Northbound Orange Line train"}

      assert ad_hoc_trip_description(:eastbound, "An-Unexpected-Route") ==
               {:ok, "Eastbound train"}
    end

    test "does not include branch letter for eastbound Green Line trips" do
      Enum.each(["Green-B", "Green-C", "Green-D", "Green-E"], fn route ->
        assert ad_hoc_trip_description(:eastbound, route) == {:ok, "Eastbound train"}

        Enum.each(
          [:lechmere, :north_station, :government_center, :park_street, :kenmore],
          fn destination ->
            assert ad_hoc_trip_description(destination, route) ==
                     {:ok,
                      "train to #{Kernel.elem(destination_to_ad_hoc_string(destination), 1)}"}
          end
        )
      end)
    end
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
end
