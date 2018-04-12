defmodule Sign.MessageTest do
  use ExUnit.Case, async: true
  import Sign.Message

  describe "headsign/1" do
    test "returns correct headsign for Mattapan trips" do
      assert headsign(0, "Mattapan", "stop1") == "Mattapan"
      assert headsign(1, "Mattapan", "stop1") == "Ashmont"
    end

    test "returns correct headsign at Ashmont" do
      assert headsign(1, "Mattapan", "70262") == "Mattapan"
    end

    test "returns correct headsign for SL3 trips" do
      assert headsign(1, "743", "74636") == "Chelsea"
      assert headsign(0, "743", "74637") == "South Sta."
    end
  end

  describe "line_code/1" do
    test "returns correct code when given integer" do
      assert line_code(1) == "1"
      assert line_code(2) == "2"
    end

    test "returns code when given atom value" do
      assert line_code(:top) == "1"
      assert line_code(:bottom) == "2"
    end
  end

  test "creates a message that can be turned into a command" do
    command = new()
              |> message("Alewife  1 min", duration: 10)
              |> message("lol not really", duration: 1)
              |> message(:canned_message, duration: 1)
              |> placement(:mezzanine, :top)
              |> placement(:center, :bottom)
              |> placement(:eastbound, 2)
              |> at_time(Timex.to_datetime({{2001, 1, 1}, {1, 2, 3}}))
              |> erase_after(45)
              |> Sign.Message.to_string

    assert command == "t3723e45~m1~c2~e2-\"Alewife  1 min\".10-\"lol not really\".1-canned_message.1"
  end

  test "does not show things that are set to nil" do
    command = new()
              |> message("Alewife  1 min")
              |> message("lol not really", duration: 1)
              |> placement(:mezzanine, :top)
              |> Sign.Message.to_string

    assert command == "~m1-\"Alewife  1 min\"-\"lol not really\".1"
  end

  test "just for fun" do
    command = new()
              |> message("LOL", duration: 1)
              |> message("LOL!", duration: 1)
              |> message("LOL!!", duration: 1)
              |> message("LOL!!!", duration: 5)
              |> erase_after(80)
              |> placement(:center, :top)
              |> Sign.Message.to_string

    assert command == "e80~c1-\"LOL\".1-\"LOL!\".1-\"LOL!!\".1-\"LOL!!!\".5"
  end
end
