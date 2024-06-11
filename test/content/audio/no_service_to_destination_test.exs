defmodule Content.Audio.NoServiceToDestinationTest do
  use ExUnit.Case, async: true

  test "Inserts destination into audio for no service" do
    [audio] =
      %Content.Message.Alert.DestinationNoService{destination: :medford_tufts}
      |> Content.Audio.NoServiceToDestination.from_message()

    assert Content.Audio.to_params(audio) == {:ad_hoc, {"No Medford/Tufts service.", :audio}}
  end

  test "Inserts destination into audio for paging shuttle alert" do
    [audio] =
      %Content.Message.Alert.NoServiceUseShuttle{destination: :medford_tufts}
      |> Content.Audio.NoServiceToDestination.from_message()

    assert Content.Audio.to_params(audio) ==
             {:ad_hoc, {"No Medford/Tufts service. Use shuttle.", :audio}}
  end
end
