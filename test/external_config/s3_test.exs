defmodule ExternalConfig.S3Test do
  use ExUnit.Case

  describe "get/1" do
    test "loads config from an external http request" do
      assert ExternalConfig.S3.get("version") == {"deadbeef1234", %{"chelsea_inbound" => %{"enabled" => true}}}
    end

    test "when it fails to get the config, uses an empty config" do
      old_value = Application.get_env(:realtime_signs, :s3_bucket)
      Application.put_env(:realtime_signs, :s3_bucket, "error")
      assert ExternalConfig.S3.get("version") == {nil, %{}}
      Application.put_env(:realtime_signs, :s3_bucket, old_value)
    end

    test "when the config is unchanged, returns :unchanged" do
      assert ExternalConfig.S3.get("unchanged") == :unchanged
    end
  end
end
