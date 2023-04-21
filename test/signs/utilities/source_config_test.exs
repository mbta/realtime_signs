defmodule Signs.Utilities.SourceConfigTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.SourceConfig

  @one_source_json """
  {
    "headway_group": "headway_group",
    "headway_direction_name": "Southbound",
    "sources": [
      {
        "stop_id": "123",
        "routes": ["Foo"],
        "direction_id": 0,
        "platform": null,
        "terminal": false,
        "announce_arriving": false,
        "announce_boarding": false
      },
      {
        "stop_id": "234",
        "routes": ["Bar"],
        "direction_id": 1,
        "platform": "ashmont",
        "terminal": true,
        "announce_arriving": true,
        "announce_boarding": false,
        "multi_berth": true
      }
    ]
  }
  """

  @two_source_json """
  [
    {
      "headway_group": "headway_group",
      "headway_direction_name": "Southbound",
      "sources": [
        {
          "stop_id": "123",
          "routes": ["Foo"],
          "direction_id": 0,
          "platform": null,
          "terminal": false,
          "announce_arriving": false,
          "announce_boarding": false
        }
      ]
    },
    {
      "headway_group": "headway_group",
      "headway_direction_name": "Southbound",
      "sources": [
        {
          "stop_id": "234",
          "headway_direction_name": "Southbound",
          "routes": ["Bar"],
          "direction_id": 1,
          "platform": "braintree",
          "terminal": true,
          "announce_arriving": true,
          "announce_boarding": true
        }
      ]
    }
  ]
  """

  @invalid_headway_destination_json """
  {
    "headway_group": "headway_group",
    "headway_direction_name": "Bar",
    "sources": [
      {
        "stop_id": "123",
        "routes": ["Foo"],
        "direction_id": 0,
        "platform": null,
        "terminal": false,
        "announce_arriving": false,
        "announce_boarding": false
      },
      {
        "stop_id": "234",
        "routes": ["Bar"],
        "direction_id": 1,
        "platform": "ashmont",
        "terminal": true,
        "announce_arriving": true,
        "announce_boarding": false,
        "multi_berth": true
      }
    ]
  }
  """

  describe "parse_one/1" do
    test "parses one source list" do
      assert @one_source_json |> Jason.decode!() |> SourceConfig.parse!() ==
               %{
                 headway_group: "headway_group",
                 headway_destination: :southbound,
                 sources: [
                   %SourceConfig{
                     stop_id: "123",
                     routes: ["Foo"],
                     direction_id: 0,
                     platform: nil,
                     terminal?: false,
                     announce_arriving?: false,
                     announce_boarding?: false,
                     multi_berth?: false
                   },
                   %SourceConfig{
                     stop_id: "234",
                     routes: ["Bar"],
                     direction_id: 1,
                     platform: :ashmont,
                     terminal?: true,
                     announce_arriving?: true,
                     announce_boarding?: false,
                     multi_berth?: true
                   }
                 ]
               }
    end

    test "parse two source lists" do
      assert @two_source_json |> Jason.decode!() |> SourceConfig.parse!() ==
               {
                 %{
                   headway_group: "headway_group",
                   headway_destination: :southbound,
                   sources: [
                     %SourceConfig{
                       stop_id: "123",
                       routes: ["Foo"],
                       direction_id: 0,
                       platform: nil,
                       terminal?: false,
                       announce_arriving?: false,
                       announce_boarding?: false
                     }
                   ]
                 },
                 %{
                   headway_group: "headway_group",
                   headway_destination: :southbound,
                   sources: [
                     %SourceConfig{
                       stop_id: "234",
                       routes: ["Bar"],
                       direction_id: 1,
                       platform: :braintree,
                       terminal?: true,
                       announce_arriving?: true,
                       announce_boarding?: true
                     }
                   ]
                 }
               }
    end

    test "logs error when headway destination is invalid" do
      assert_raise MatchError, fn ->
        @invalid_headway_destination_json |> Jason.decode!() |> SourceConfig.parse!() ==
          %{
            headway_group: "headway_group",
            headway_destination: nil,
            sources: [
              %SourceConfig{
                stop_id: "123",
                routes: ["Foo"],
                direction_id: 0,
                platform: nil,
                terminal?: false,
                announce_arriving?: false,
                announce_boarding?: false,
                multi_berth?: false
              },
              %SourceConfig{
                stop_id: "234",
                routes: ["Bar"],
                direction_id: 1,
                platform: :ashmont,
                terminal?: true,
                announce_arriving?: true,
                announce_boarding?: false,
                multi_berth?: true
              }
            ]
          }
      end
    end
  end

  describe "sign_stop_ids" do
    test "pull stop ids from config" do
      Enum.map([@one_source_json, @two_source_json], fn json ->
        assert json
               |> Jason.decode!()
               |> SourceConfig.parse!()
               |> SourceConfig.sign_stop_ids() == ["123", "234"]
      end)
    end
  end

  describe "sign_routes" do
    test "pull routes from config" do
      Enum.map([@one_source_json, @two_source_json], fn json ->
        assert json
               |> Jason.decode!()
               |> SourceConfig.parse!()
               |> SourceConfig.sign_routes() == ["Foo", "Bar"]
      end)
    end
  end
end
