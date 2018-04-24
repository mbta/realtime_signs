defmodule Content.Audio.ChelseaBridgeRaisedDelaysTest do
  use ExUnit.Case, async: true

  test "Chelsea bridge delays in English" do
    audio = %Content.Audio.ChelseaBridgeRaisedDelays{
      language: :english,
      delay_minutes: 5
    }
    assert Content.Audio.to_params(audio) == {"135", ["5505"]}
  end

  test "Chelsea bridge delays in Spanish" do
    audio = %Content.Audio.ChelseaBridgeRaisedDelays{
      language: :spanish,
      delay_minutes: 5
    }
    assert Content.Audio.to_params(audio) == {"152", ["37005"]}
  end
end
