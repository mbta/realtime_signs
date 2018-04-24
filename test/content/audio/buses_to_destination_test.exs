defmodule Content.Audio.BusesToDestinationTest do
  use ExUnit.Case, async: true

  test "Buses to Chelsea in English" do
    audio = %Content.Audio.BusesToDestination{
      destination: :chelsea,
      language: :english,
      next_bus_mins: 7,
      later_bus_mins: 10
    }
    assert Content.Audio.to_params(audio) == {"133", ["5507", "5510"]}
  end

  test "Buses to Chelsea in Spanish" do
    audio = %Content.Audio.BusesToDestination{
      destination: :chelsea,
      language: :spanish,
      next_bus_mins: 7,
      later_bus_mins: 10
    }
    assert Content.Audio.to_params(audio) == {"150", ["37007", "37010"]}
  end

  test "Buses to South Station in English" do
    audio = %Content.Audio.BusesToDestination{
      destination: :south_station,
      language: :english,
      next_bus_mins: 7,
      later_bus_mins: 10
    }
    assert Content.Audio.to_params(audio) == {"134", ["5507", "5510"]}
  end

  test "Buses to South Station in Spanish" do
    audio = %Content.Audio.BusesToDestination{
      destination: :south_station,
      language: :spanish,
      next_bus_mins: 7,
      later_bus_mins: 10
    }
    assert Content.Audio.to_params(audio) == {"151", ["37007", "37010"]}
  end
end
