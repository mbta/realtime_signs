defmodule ExternalConfig.LocalTest do
  use ExUnit.Case

  describe "get/1" do
    test "loads config from a local json file" do
      assert ExternalConfig.Local.get("version") ==
               {"92201010",
                %{
                  "signs" => %{
                    "chelsea_inbound" => %{"mode" => "auto"},
                    "chelsea_outbound" => %{"mode" => "off"}
                  }
                }}
    end

    test "if the file is unchanged, returns :unchanged" do
      assert ExternalConfig.Local.get("92201010") == :unchanged
    end
  end
end
