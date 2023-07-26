defmodule Content.Audio.FirstTrainScheduledTest do
  use ExUnit.Case, async: true

  describe "Content.Audio.to_params protocol" do
    test "First train to Ashmont scheduled to arrive at 5 o'clock" do
      audio = %Content.Audio.FirstTrainScheduled{
        destination: :ashmont,
        scheduled_time: ~U[2023-07-19 05:00:00Z]
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115",
                 [
                   "866",
                   "21000",
                   "4016",
                   "21000",
                   "864",
                   "21000",
                   "533",
                   "21000",
                   "865",
                   "21000",
                   "8004",
                   "21000",
                   "9000"
                 ], :audio}}
    end

    test "First train to Ashmont scheduled to arrive at 5 oh 5" do
      audio = %Content.Audio.FirstTrainScheduled{
        destination: :ashmont,
        scheduled_time: ~U[2023-07-19 05:05:00Z]
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115",
                 [
                   "866",
                   "21000",
                   "4016",
                   "21000",
                   "864",
                   "21000",
                   "533",
                   "21000",
                   "865",
                   "21000",
                   "8004",
                   "21000",
                   "9005"
                 ], :audio}}
    end
  end
end
