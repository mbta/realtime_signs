defmodule Sign.PlatformsTest do
  use ExUnit.Case, async: true
  alias Sign.Platforms
  import Sign.Platforms

  test "a struct gets turned into a bitstring" do
    string = Sign.Platforms.new
             |> set(:northbound, true)
             |> set(:mezzanine, true)
             |> set(:westbound, true)
             |> Sign.Platforms.to_string

    assert string == "101001"
  end

  describe "from_zones/1" do
    test "builds platforms struct from given zones" do
      zones = [:eastbound, :westbound, :center]
      assert from_zones(zones) == %Platforms{eb: true, wb: true, cp: true, nb: false, sb: false, mz: false}
    end
  end
end
