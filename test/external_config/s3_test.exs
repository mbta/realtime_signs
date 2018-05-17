defmodule ExternalConfig.S3Test do
  use ExUnit.Case

  describe "get/0" do
    test "loads config from an external http request" do
      assert ExternalConfig.S3.get() == %{"chelsea_inbound" => %{"enabled" => true}}
    end
  end
end
