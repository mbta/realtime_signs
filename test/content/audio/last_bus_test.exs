defmodule Content.Audio.LastBusTest do
  use ExUnit.Case, async: true

  test "Last bus to Chelsea" do
    audio = %Content.Audio.LastBus{
      destination: :chelsea,
      minutes: 10,
    }
    assert Content.Audio.to_params(audio) == {"137", ["9110"]}
  end

  test "Last bus to South Station" do
    audio = %Content.Audio.LastBus{
      destination: :south_station,
      minutes: 10,
    }
    assert Content.Audio.to_params(audio) == {"138", ["9110"]}
  end
end
