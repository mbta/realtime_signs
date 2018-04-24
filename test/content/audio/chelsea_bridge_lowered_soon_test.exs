defmodule Content.Audio.ChelseaBridgeLoweredSoonTest do
  use ExUnit.Case, async: true

  test "bridge will be lowered soon" do
    audio = %Content.Audio.ChelseaBridgeLoweredSoon{}
    assert Content.Audio.to_params(audio) == {"136", []}
  end
end
