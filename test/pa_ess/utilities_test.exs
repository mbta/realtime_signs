defmodule Content.Audio.UtilitiesTest do
  use ExUnit.Case, async: true

  import PaEss.Utilities

  test "headsign_to_destination/1" do
    assert headsign_to_destination("Alewife") == "place-alfcl"
    assert headsign_to_destination("Riverside") == "place-river"
  end

  test "destination_to_sign_string/1" do
    assert destination_to_sign_string("place-forhl") == "Frst Hills"
    assert destination_to_sign_string(:southbound) == "Southbound"
  end

  test "destination_to_tts_string/1" do
    assert destination_to_tts_string("place-hsmnl") == "Heath Street"
    assert destination_to_tts_string(:southbound) == "Southbound"
  end

  test "paginate_text" do
    assert [{"Attention passengers:", "the next Braintree train", 3}, {"is now arriving", "", 3}] =
             paginate_text("Attention passengers: the next Braintree train is now arriving", 24)

    assert [{"too-long", "word", 3}] = paginate_text(" too-long   word ", 5)
    assert [{"fits", "", 3}] = paginate_text("fits", 24)
    assert [] = paginate_text("")
  end
end
