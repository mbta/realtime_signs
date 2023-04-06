defmodule ExternalConfig.LocalTest do
  use ExUnit.Case

  describe "get/1" do
    test "loads config from a local json file" do
      assert ExternalConfig.Local.get("version") ==
               {"29027168",
                %{
                  "signs" => %{
                    "chelsea_inbound" => %{"mode" => "headway"},
                    "chelsea_outbound" => %{"mode" => "off"},
                    "MVAL0" => %{"mode" => "auto"}
                  }
                }}
    end

    test "if the file is unchanged, returns :unchanged" do
      assert ExternalConfig.Local.get("29027168") == :unchanged
    end
  end
end
