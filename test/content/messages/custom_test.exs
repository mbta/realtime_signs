defmodule Content.Message.CustomTest do
  use ExUnit.Case, async: true

  test "deserializes back to the original string" do
    msg = Content.Message.Custom.new("Test message")
    assert Content.Message.to_string(msg) == "Test message"
  end
end
