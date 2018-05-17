defmodule ExternalConfig.S3Test do
  use ExUnit.Case

  describe "get/0" do
    test "loads config from an external http request" do
      assert ExternalConfig.S3.get() == %{"chelsea_inbound" => %{"enabled" => true}}
    end

    test "when it fails to get the config, uses an empty config" do
      old_value = Application.get_env(:realtime_signs, :s3_bucket)
      Application.put_env(:realtime_signs, :s3_bucket, "error")
      assert ExternalConfig.S3.get() == %{}
      Application.put_env(:realtime_signs, :s3_bucket, old_value)
    end
  end
end
