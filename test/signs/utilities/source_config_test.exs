defmodule Signs.Utilities.SourceConfigTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.SourceConfig

  describe "parse_one/1" do
    test "parses one source list" do
      json = """
      [
        [
          {
            "stop_id": "123",
            "direction_id": 0,
            "headway_direction_name": "Southbound",
            "platform": null,
            "terminal": false,
            "announce_arriving": false
          },
          {
            "stop_id": "234",
            "headway_direction_name": "Southbound",
            "direction_id": 1,
            "platform": "ashmont",
            "terminal": true,
            "announce_arriving": true,
            "multi_berth": true
          }
        ]
      ]
      """

      assert json |> Poison.Parser.parse!() |> SourceConfig.parse!() ==
               {
                 [
                   %SourceConfig{
                     stop_id: "123",
                     headway_direction_name: "Southbound",
                     direction_id: 0,
                     platform: nil,
                     terminal?: false,
                     announce_arriving?: false,
                     multi_berth?: false
                   },
                   %SourceConfig{
                     stop_id: "234",
                     headway_direction_name: "Southbound",
                     direction_id: 1,
                     platform: :ashmont,
                     terminal?: true,
                     announce_arriving?: true,
                     multi_berth?: true
                   }
                 ]
               }
    end

    test "parse two source lists" do
      json = """
      [
        [
          {
            "stop_id": "123",
            "headway_direction_name": "Southbound",
            "direction_id": 0,
            "platform": null,
            "terminal": false,
            "announce_arriving": false
          }
        ],
        [
          {
            "stop_id": "234",
            "headway_direction_name": "Southbound",
            "direction_id": 1,
            "platform": "braintree",
            "terminal": true,
            "announce_arriving": true
          }
        ]
      ]
      """

      assert json |> Poison.Parser.parse!() |> SourceConfig.parse!() ==
               {
                 [
                   %SourceConfig{
                     stop_id: "123",
                     headway_direction_name: "Southbound",
                     direction_id: 0,
                     platform: nil,
                     terminal?: false,
                     announce_arriving?: false
                   }
                 ],
                 [
                   %SourceConfig{
                     stop_id: "234",
                     headway_direction_name: "Southbound",
                     direction_id: 1,
                     platform: :braintree,
                     terminal?: true,
                     announce_arriving?: true
                   }
                 ]
               }
    end
  end
end
