defmodule Content.Message.Alert.NoServiceTest do
  use ExUnit.Case, async: true

  describe "to_string" do
    test "serializes modes correctly" do
      msg = %Content.Message.Alert.NoService{}
      assert Content.Message.to_string(msg) == "No train service"
    end
  end
end
