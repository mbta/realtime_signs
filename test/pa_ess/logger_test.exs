defmodule PaEss.LoggerTest do
  use ExUnit.Case, async: true

  test "Logger behaviour runs without crashing" do
    assert {:ok, :sent} =
             PaEss.Logger.update_single_line(
               {"a", "b"},
               "1",
               Content.Message.Empty.new(),
               60,
               :now
             )
  end

  test "Logger behaviour runs without crashing for whole sign" do
    top_line = Content.Message.Empty.new()
    bottom_line = Content.Message.Empty.new()
    assert {:ok, :sent} = PaEss.Logger.update_sign({"a", "b"}, top_line, bottom_line, 60, :now)
  end

  test "Logger behaviour runs without crashing for audio" do
    assert {:ok, :sent} =
             PaEss.Logger.send_audio(
               {"a", "b"},
               [%Content.Audio.StoppedTrain{destination: :alewife, stops_away: 5}],
               5,
               60
             )
  end

  test "Logger behaviour runs without crashing for audio tuples" do
    assert {:ok, :sent} =
             PaEss.Logger.send_audio(
               {"a", "b"},
               [
                 %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 5},
                 %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 5}
               ],
               5,
               60
             )
  end
end
