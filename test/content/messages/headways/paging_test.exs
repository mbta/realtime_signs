defmodule Content.Message.Headways.PagingTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "When destination is not nil, page headways with destination" do
      assert Content.Message.to_string(%Content.Message.Headways.Paging{
               destination: :heath_street,
               range: {5, 7}
             }) == [
               {"Heath St    trains every", 3},
               {"Heath St      5 to 7 min", 3}
             ]
    end

    test "When destination is nil, page generic headway message" do
      assert Content.Message.to_string(%Content.Message.Headways.Paging{
               destination: nil,
               range: {5, 7}
             }) == [
               {"Trains every", 3},
               {"5 to 7 min", 3}
             ]
    end
  end
end
