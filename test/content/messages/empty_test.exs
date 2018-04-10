defmodule Content.Message.EmptyTest do
  use ExUnit.Case, async: true

  test "serializes to an empty string" do
    msg = Content.Message.Empty.new()
    assert Content.Message.to_string(msg) == ""
  end
end
