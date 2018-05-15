defmodule ExternalConfig.LocalTest do
  use ExUnit.Case

  describe "get/0" do
    test "loads config from a local json file" do
      assert ExternalConfig.Local.get() == %{"chelsea_inbound" => %{"enabled" => true}, "chelsea_outbound" => %{"enabled" => false}}
    end
  end
end
