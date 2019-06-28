defmodule Headway.ObservedHeadwayFetcherTest do
  use ExUnit.Case
  import Test.Support.Helpers
  alias Headway.ObservedHeadwayFetcher

  describe "fetch/0" do
    test "parses the body when the request is successful" do
      assert ObservedHeadwayFetcher.fetch() == {
               :ok,
               %{
                 "alewife" => [12, 34],
                 "ashmont" => [56, 78],
                 "bowdoin" => [90, 1011],
                 "braintree" => [1213, 1415],
                 "forest_hills" => [1617, 1819],
                 "oak_grove" => [2021, 2223],
                 "wonderland" => [2425, 2627]
               }
             }
    end

    test "returns an error when status code 300 or above" do
      reassign_env(
        :recent_headways_url,
        "https://www.example.com/bad-headways-300.json"
      )

      assert ObservedHeadwayFetcher.fetch() == :error
    end

    test "returns an error when request fails for miscellaneous reaasons" do
      reassign_env(
        :recent_headways_url,
        "https://www.nonexistent_domain.com/headways.json"
      )

      assert ObservedHeadwayFetcher.fetch() == :error
    end

    test "returns an error when JSON parsing fails" do
      reassign_env(
        :recent_headways_url,
        "https://www.example.com/malformed_headways.json"
      )

      assert ObservedHeadwayFetcher.fetch() == :error
    end
  end
end
