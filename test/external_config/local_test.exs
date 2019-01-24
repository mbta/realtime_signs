defmodule ExternalConfig.LocalTest do
  use ExUnit.Case

  describe "get/1" do
    test "loads config from a local json file" do
      assert ExternalConfig.Local.get("version") ==
               {"47052743",
                %{
                  "chelsea_inbound" => %{"mode" => "headway"},
                  "chelsea_outbound" => %{"mode" => "off"},
                  "MVAL0" => %{"mode" => "auto"}
                }}
    end

    test "uses a hash of the file as a version id" do
      assert ExternalConfig.Local.get(nil) ==
               {"47052743",
                %{
                  "chelsea_inbound" => %{"mode" => "headway"},
                  "chelsea_outbound" => %{"mode" => "off"},
                  "MVAL0" => %{"mode" => "auto"}
                }}
    end

    test "if the file is unchanged, returns :unchanged" do
      assert ExternalConfig.Local.get("47052743") == :unchanged
    end
  end
end
