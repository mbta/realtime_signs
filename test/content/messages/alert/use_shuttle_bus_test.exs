defmodule Content.Message.Alert.UseShuttleBusTest do
  use ExUnit.Case, async: true

  describe "to_string" do
    test "serializes modes correctly" do
      msg = %Content.Message.Alert.UseShuttleBus{}
      assert Content.Message.to_string(msg) == "Use shuttle bus"
    end
  end
end
