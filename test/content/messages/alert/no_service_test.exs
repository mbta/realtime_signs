defmodule Content.Message.Alert.NoServiceTest do
  use ExUnit.Case, async: true

  describe "to_string" do
    test "defaults to train" do
      msg = %Content.Message.Alert.NoService{}
      assert Content.Message.to_string(msg) == "No train service"
    end

    test "can omit the mode" do
      msg = %Content.Message.Alert.NoService{mode: nil}
      assert Content.Message.to_string(msg) == "No service"
    end
  end
end
