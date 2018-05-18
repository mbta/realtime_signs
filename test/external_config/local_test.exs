defmodule ExternalConfig.LocalTest do
  use ExUnit.Case

  describe "get/1" do
    test "loads config from a local json file" do
      assert ExternalConfig.Local.get("version") == {nil, %{"chelsea_inbound" => %{"enabled" => true}, "chelsea_outbound" => %{"enabled" => true}, "MVAL0" => %{"enabled" => true}}}
    end
  end
end
