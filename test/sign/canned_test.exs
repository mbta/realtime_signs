defmodule Sign.CannedTest do
  use ExUnit.Case, async: true

  import Sign.Canned

  test "creates a message as a command" do
    command = new()
    |> priority(4)
    |> station("MMIL")
    |> platforms(:southbound)
    |> platforms(:northbound)
    |> mid(90015)
    |> timeout(30)
    |> to_command

    assert command == [
      MsgType: "Canned",
      mid: 90015,
      var: "",
      typ: "0",
      sta: "MMIL001100",
      pri: 4,
      tim: 30
    ]
  end

  test "adds time fields only if specified" do
    now = ~N[2017-05-22 12:34:56]
    today = Timex.to_date(now)
    command = new()
    |> station("MBUT")
    |> platforms(:southbound)
    |> mid(90128)
    |> start_time(now)
    |> end_time(Timex.shift(now, minutes: 5))
    |> start_date(today)
    |> end_date(Timex.shift(today, days: 1))
    |> to_command

    assert command == [
      MsgType: "Canned",
      ent: "1239PM",
      stt: "1234PM",
      end: "05232017",
      std: "05222017",
      mid: 90128,
      var: "",
      typ: "0",
      sta: "MBUT000100",
      pri: 5,
      tim: 60
    ]
  end

  test "interval is rendered as HH:MM:SS" do
    command = new()
    |> priority(4)
    |> station("MMIL")
    |> platforms(:southbound)
    |> interval(1 * 3600 + 2 * 60 + 3) # 5 minutes
    |> to_command

    assert Keyword.get(command, :int) == "01:02:03"
  end
end
