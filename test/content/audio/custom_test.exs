defmodule Content.Audio.CustomTest do
  use ExUnit.Case, async: true

  test "Makes an audio message when both lines are custom" do
    top = %Content.Message.Custom{
      line: :top,
      message: "Top Message"
    }

    bottom = %Content.Message.Custom{
      line: :bottom,
      message: "Bottom Message"
    }

    assert Content.Audio.Custom.from_messages(top, bottom) == %Content.Audio.Custom{
             message: "Top Message Bottom Message"
           }
  end

  test "Makes an audio message when the top is empty" do
    top = %Content.Message.Empty{}

    bottom = %Content.Message.Custom{
      line: :bottom,
      message: "Bottom Message"
    }

    assert Content.Audio.Custom.from_messages(top, bottom) == %Content.Audio.Custom{
             message: "Bottom Message"
           }
  end

  test "Makes an audio message when the bottom is empty" do
    top = %Content.Message.Custom{
      line: :top,
      message: "Top Message"
    }

    bottom = %Content.Message.Empty{}

    assert Content.Audio.Custom.from_messages(top, bottom) == %Content.Audio.Custom{
             message: "Top Message"
           }
  end
end
