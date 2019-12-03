defmodule Signs.Utilities.SourceConfigTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.SourceConfig

  @one_source_json """
  [
    [
      {
        "stop_id": "123",
        "routes": ["Foo"],
        "direction_id": 0,
        "headway_direction_name": "Southbound",
        "platform": null,
        "terminal": false,
        "announce_arriving": false,
        "announce_boarding": false
      },
      {
        "stop_id": "234",
        "headway_direction_name": "Southbound",
        "routes": ["Bar"],
        "direction_id": 1,
        "platform": "ashmont",
        "terminal": true,
        "announce_arriving": true,
        "announce_boarding": false,
        "multi_berth": true
      }
    ]
  ]
  """

  @two_source_json """
  [
    [
      {
        "stop_id": "123",
        "headway_direction_name": "Southbound",
        "routes": ["Foo"],
        "direction_id": 0,
        "platform": null,
        "terminal": false,
        "announce_arriving": false,
        "announce_boarding": false
      }
    ],
    [
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
  ]
  """

  describe "parse_one/1" do
    test "parses one source list" do
      assert @one_source_json |> Jason.decode!() |> SourceConfig.parse!() ==
               {
                 [
                   %SourceConfig{
                     stop_id: "123",
                     headway_direction_name: "Southbound",
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
                     headway_direction_name: "Southbound",
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
                 [
                   %SourceConfig{
                     stop_id: "123",
                     headway_direction_name: "Southbound",
                     routes: ["Foo"],
                     direction_id: 0,
                     platform: nil,
                     terminal?: false,
                     announce_arriving?: false,
                     announce_boarding?: false
                   }
                 ],
                 [
                   %SourceConfig{
                     stop_id: "234",
                     headway_direction_name: "Southbound",
                     routes: ["Bar"],
                     direction_id: 1,
                     platform: :braintree,
                     terminal?: true,
                     announce_arriving?: true,
                     announce_boarding?: true
                   }
                 ]
               }
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

  describe "transit_mode_for_routes/1" do
    test "Returns :train if any of the routes isn't a Silver Line route" do
      assert SourceConfig.transit_mode_for_routes(["Red"]) == :train
      assert SourceConfig.transit_mode_for_routes(["Orange", "741"]) == :train
    end

    test "Returns :bus when all routes are Silver Line" do
      assert SourceConfig.transit_mode_for_routes(["741", "742"]) == :bus
    end

    test "Returns :bus when no routes given" do
      assert SourceConfig.transit_mode_for_routes([]) == :bus
    end
  end
end
