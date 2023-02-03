defmodule Content.Audio.NoServiceToDestinationTest do
  use ExUnit.Case, async: true

  test "Inserts destination into audio for no service" do
    message = %Content.Message.Alert.DestinationNoService{
      destination: :medford_tufts
    }

    assert Content.Audio.NoServiceToDestination.from_message(message) ==
             %Content.Audio.NoServiceToDestination{
               message: "No service to Medford/Tufts"
             }
  end

  test "Inserts destination into audio for paging shuttle alert" do
    message = %Content.Message.Alert.NoServiceUseShuttle{
      destination: :medford_tufts
    }

    assert Content.Audio.NoServiceToDestination.from_message(message) ==
             %Content.Audio.NoServiceToDestination{
               message: "No service to Medford/Tufts use shuttle"
             }
  end
end
