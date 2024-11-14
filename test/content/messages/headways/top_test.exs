defmodule Content.Message.Headways.TopTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "works" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :alewife,
               route: "Red"
             }) ==
               "Alewife trains"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: nil,
               route: "Mattapan"
             }) ==
               "Mattapan trains"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: nil,
               route: "Red"
             }) ==
               "Red line trains"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: nil,
               route: nil
             }) ==
               "Trains"
    end
  end
end
