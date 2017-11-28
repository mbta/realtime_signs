defmodule Sign.PlatformsTest do
  use ExUnit.Case, async: true

  test "a struct gets turned into a bitstring" do
    string = Sign.Platforms.new
             |> Sign.Platforms.set(:northbound, true)
             |> Sign.Platforms.set(:mezzanine, true)
             |> Sign.Platforms.set(:westbound, true)
             |> Sign.Platforms.to_string

    assert string == "101001"
  end
end
