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
          %Headway{headway_id: {"A", :peak}, range_low: 8, range_high: 10},
          %Headway{headway_id: {"B", :off_peak}, range_low: 10, range_high: 12}
        ])

      assert %Headway{headway_id: {"A", :peak}, range_low: 8, range_high: 10} =
               Headways.get_headway(table, {"A", :peak})

      assert %Headway{headway_id: {"B", :off_peak}, range_low: 10, range_high: 12} =
               Headways.get_headway(table, {"B", :off_peak})

      :ok =
        Headways.update_table(table, [
          %Headway{headway_id: {"B", :off_peak}, range_low: 12, range_high: 14},
          %Headway{headway_id: {"C", :peak}, range_low: 8, range_high: 10}
        ])

      refute Headways.get_headway(table, {"A", :peak})

      assert %Headway{headway_id: {"B", :off_peak}, range_low: 12, range_high: 14} =
               Headways.get_headway(table, {"B", :off_peak})

      assert %Headway{headway_id: {"C", :peak}, range_low: 8, range_high: 10} =
               Headways.get_headway(table, {"C", :peak})
    end
  end

  describe "parse/1" do
    test "parses data and ignores invalid entries" do
      data = %{
        "red_trunk" => %{
          "peak" => %{
            "range_low" => 8,
            "range_high" => 10
          },
          "off_peak" => %{
            "range_low" => 12,
            "range_high" => 15
          }
        },
        "red_braintree" => %{
          "peak" => %{
            "range_low" => 16,
            "range_high" => 20
          },
          "off_peak" => %{
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
               %Headway{headway_id: {"red_braintree", :off_peak}, range_low: 24, range_high: 30},
               %Headway{headway_id: {"red_braintree", :peak}, range_low: 16, range_high: 20},
               %Headway{headway_id: {"red_trunk", :off_peak}, range_low: 12, range_high: 15},
               %Headway{headway_id: {"red_trunk", :peak}, range_low: 8, range_high: 10}
             ] = Enum.sort(headways)
    end
  end
end
