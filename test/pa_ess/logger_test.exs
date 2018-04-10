defmodule PaEss.LoggerTest do
  use ExUnit.Case, async: true

  test "Logger behaviour runs without crashing" do
    assert {:ok, :sent} = PaEss.Logger.update_sign({"a", "b"}, "1", Content.Message.Empty.new(), 60, :now)
  end
end
