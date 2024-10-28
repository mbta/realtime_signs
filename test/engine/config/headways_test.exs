defmodule Engine.Config.HeadwaysTest do
  use ExUnit.Case
  alias Engine.Config.Headway
  alias Engine.Config.Headways

  describe "working with ETS tables" do
    test "updating a table adds new records, updates existing, and deletes old ones" do
      table = :config_headways_test
      ^table = Headways.create_table(table)

      :ok =
        Headways.update_table(table, [
          %Headway{headway_id: {"A", :weekday}, range_low: 8, range_high: 10},
          %Headway{headway_id: {"B", :saturday}, range_low: 10, range_high: 12}
        ])

      assert %Headway{headway_id: {"A", :weekday}, range_low: 8, range_high: 10} =
               Headways.get_headway(table, {"A", :weekday})

      assert %Headway{headway_id: {"B", :saturday}, range_low: 10, range_high: 12} =
               Headways.get_headway(table, {"B", :saturday})

      :ok =
        Headways.update_table(table, [
          %Headway{headway_id: {"B", :saturday}, range_low: 12, range_high: 14},
          %Headway{headway_id: {"C", :weekday}, range_low: 8, range_high: 10}
        ])

      refute Headways.get_headway(table, {"A", :weekday})

      assert %Headway{headway_id: {"B", :saturday}, range_low: 12, range_high: 14} =
               Headways.get_headway(table, {"B", :saturday})

      assert %Headway{headway_id: {"C", :weekday}, range_low: 8, range_high: 10} =
               Headways.get_headway(table, {"C", :weekday})
    end
  end

  describe "parse/1" do
    test "parses data and ignores invalid entries" do
      data = %{
        "red_trunk" => %{
          "weekday" => %{
            "range_low" => 8,
            "range_high" => 10
          },
          "saturday" => %{
            "range_low" => 12,
            "range_high" => 15
          }
        },
        "red_braintree" => %{
          "weekday" => %{
            "range_low" => 16,
            "range_high" => 20
          },
          "saturday" => %{
            "range_low" => 24,
            "range_high" => 30
          },
          "invalid" => %{
            "range_medium" => 10
          }
        }
      }

      headways = Headways.parse(data)

      assert [
               %Headway{headway_id: {"red_braintree", :saturday}, range_low: 24, range_high: 30},
               %Headway{headway_id: {"red_braintree", :weekday}, range_low: 16, range_high: 20},
               %Headway{headway_id: {"red_trunk", :saturday}, range_low: 12, range_high: 15},
               %Headway{headway_id: {"red_trunk", :weekday}, range_low: 8, range_high: 10}
             ] = Enum.sort(headways)
    end
  end
end
