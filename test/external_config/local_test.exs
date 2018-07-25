defmodule ExternalConfig.LocalTest do
  use ExUnit.Case

  describe "get/1" do
    test "loads config from a local json file" do
      assert ExternalConfig.Local.get("version") ==
               {"34956243",
                %{
                  "chelsea_inbound" => %{"enabled" => true},
                  "chelsea_outbound" => %{"enabled" => true},
                  "MVAL0" => %{"enabled" => true}
                }}
    end

    test "uses a hash of the file as a version id" do
      assert ExternalConfig.Local.get(nil) ==
               {"34956243",
                %{
                  "chelsea_inbound" => %{"enabled" => true},
                  "chelsea_outbound" => %{"enabled" => true},
                  "MVAL0" => %{"enabled" => true}
                }}
    end

    test "if the file is unchanged, returns :unchanged" do
      assert ExternalConfig.Local.get("34956243") == :unchanged
    end
  end
end
