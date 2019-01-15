defmodule Content.Message.CustomTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  test "deserializes back to the original string" do
    msg = Content.Message.Custom.new("Test message", :top)
    assert Content.Message.to_string(msg) == "Test message"
  end

  test "rejects string that is too long" do
    log =
      capture_log([level: :error], fn ->
        msg = Content.Message.Custom.new("Test message and more random stuff", :top)
        assert Content.Message.to_string(msg) == ""
      end)

    assert log =~ "Invalid custom message"
  end

  test "rejects string that contains invalid characters" do
    log =
      capture_log([level: :error], fn ->
        msg = Content.Message.Custom.new("Test message^", :top)
        assert Content.Message.to_string(msg) == ""
      end)

    assert log =~ "Invalid custom message"
  end
end
