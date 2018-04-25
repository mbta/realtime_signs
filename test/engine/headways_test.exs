defmodule Engine.HeadwaysTest do
  use ExUnit.Case
  describe "register callback" do
    test "adds the stop id to the state" do
      assert Engine.Headways.handle_call({:register, "123"}, %{}, %{}) == {:ok, %{"123" => %{}}}
    end
  end
end
