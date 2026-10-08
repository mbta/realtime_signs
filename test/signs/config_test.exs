defmodule Signs.ConfigTest do
  use ExUnit.Case, async: true

  @json """
  {
    "headway_group": "headway_group",
    "headway_direction_name": "Southbound",
    "destination": "Southbound",
    "terminal": false,
    "sources": [
      {
        "stop_id": "123",
        "route_id": "Foo",
        "direction_id": 0
      },
      {
        "stop_id": "234",
        "route_id": "Bar",
        "direction_id": 1
      }
    ],
    "announce_arriving": true,
    "announce_boarding": false
  }
  """

  test "parse!/1" do
    assert JSON.decode!(@json) |> Signs.Config.parse!() ==
             %Signs.Config{
               headway_group: "headway_group",
               headway_destination: :southbound,
               destination: :southbound,
               terminal?: false,
               sources: [
                 %Signs.Config.Source{
                   stop_id: "123",
                   route_id: "Foo",
                   direction_id: 0
                 },
                 %Signs.Config.Source{
                   stop_id: "234",
                   route_id: "Bar",
                   direction_id: 1
                 }
               ],
               announce_arriving?: true,
               announce_boarding?: false
             }
  end
end
