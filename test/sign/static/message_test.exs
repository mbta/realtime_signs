defmodule Sign.Static.MessageTest do
  use ExUnit.Case, async: true
  import Sign.Static.Message

  describe "from_map/1" do
    test "builds struct from map" do
      static_text_map = %{"direction" =>  0, "top_text" => "top text", "bottom_text" => "bottom text"}
      expected = %Sign.Static.Message{
        station_id: "70262",
        sign_id: "RASH",
        direction: 0,
        top_text: "top text",
        bottom_text: "bottom text"
      }
      assert from_map({"70262", static_text_map}) == expected
    end
  end
end
