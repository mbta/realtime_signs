defmodule Content.Audio.UtilitiesTest do
  use ExUnit.Case, async: true

  import PaEss.Utilities

  test "number_var/2" do
    assert number_var(10, :english) == {:ok, "5510"}
    assert number_var(10, :spanish) == {:ok, "37010"}
    assert number_var(1000, :english) == {:error, :invalid}
  end

  test "time_var/1" do
    assert time_var(10) == "9110"
  end

  test "countdown_minutes_var/1" do
    assert countdown_minutes_var(10) == "5010"
  end
end
