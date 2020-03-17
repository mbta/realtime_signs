defmodule Engine.Config.HeadwayTest do
  use ExUnit.Case, async: true
  alias Engine.Config.Headway

  describe "from_map/2" do
    test "parses successfully" do
      assert Headway.from_map("A", %{"range_low" => 5, "range_high" => 10}) ==
               {:ok, %Headway{group_id: "A", range_low: 5, range_high: 10}}
    end

    test "returns error for invalid data" do
      assert Headway.from_map("A", %{}) == :error
    end

    test "includes non-platform text if present" do
      assert Headway.from_map("A", %{
               "range_low" => 5,
               "range_high" => 10,
               "non_platform_text_line1" => "line1",
               "non_platform_text_line2" => "line2"
             }) ==
               {:ok,
                %Headway{
                  group_id: "A",
                  range_low: 5,
                  range_high: 10,
                  non_platform_text_line1: "line1",
                  non_platform_text_line2: "line2"
                }}
    end
  end
end
