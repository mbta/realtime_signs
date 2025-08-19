defmodule Content.Audio.PassthroughTest do
  use ExUnit.Case, async: true

  alias Content.Audio.Passthrough

  describe "to_params/1" do
    test "Returns params" do
      assert Content.Audio.to_params(%Passthrough{destination: :alewife, route_id: "Red"}) ==
               {:canned,
                {"112",
                 [
                   "501",
                   "21000",
                   "892",
                   "21000",
                   "920",
                   "21000",
                   "933",
                   "21014",
                   "21000",
                   "925"
                 ], :audio_visual}}
    end
  end
end
