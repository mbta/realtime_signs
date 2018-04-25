defmodule PaEss.LoggerTest do
  use ExUnit.Case, async: true

  test "Logger behaviour runs without crashing" do
    assert {:ok, :sent} = PaEss.Logger.update_sign({"a", "b"}, "1", Content.Message.Empty.new(), 60, :now)
  end

  test "Logger behaviour runs without crashing for audio" do
    assert {:ok, :sent} = PaEss.Logger.send_audio({"a", "b"}, %Content.Audio.ChelseaBridgeLoweredSoon{}, 5, :audio, 60)
  end
end
