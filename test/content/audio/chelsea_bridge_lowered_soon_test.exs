defmodule Content.Audio.ChelseaBridgeLoweredSoonTest do
  use ExUnit.Case, async: true

  test "bridge will be lowered soon, in English" do
    audio = %Content.Audio.ChelseaBridgeLoweredSoon{language: :english}
    assert Content.Audio.to_params(audio) == {"136", []}
  end

  test "bridge will be lowered soon, in Spanish" do
    audio = %Content.Audio.ChelseaBridgeLoweredSoon{language: :spanish}
    assert Content.Audio.to_params(audio) == {"157", []}
  end
end
