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
          %Headway{group_id: "A", range_low: 8, range_high: 10},
          %Headway{group_id: "B", range_low: 10, range_high: 12}
        ])

      assert %Headway{group_id: "A", range_low: 8, range_high: 10} =
               Headways.get_headway(table, "A")

      assert %Headway{group_id: "B", range_low: 10, range_high: 12} =
               Headways.get_headway(table, "B")

      :ok =
        Headways.update_table(table, [
          %Headway{group_id: "B", range_low: 12, range_high: 14},
          %Headway{group_id: "C", range_low: 8, range_high: 10}
        ])

      refute Headways.get_headway(table, "A")

      assert %Headway{group_id: "B", range_low: 12, range_high: 14} =
               Headways.get_headway(table, "B")

      assert %Headway{group_id: "C", range_low: 8, range_high: 10} =
               Headways.get_headway(table, "C")
    end
  end
end
