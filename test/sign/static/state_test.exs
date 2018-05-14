defmodule Sign.Static.StateTest do
  use ExUnit.Case

  import Sign.Static.State

  describe "handle_info/2" do
    test "handles info :refresh" do
      assert handle_info({:refresh, 12345}, %{}) == {:noreply, %{}}
    end
  end
end
