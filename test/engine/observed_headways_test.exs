defmodule Engine.ObservedHeadwaysTest do
  use ExUnit.Case
  import Test.Support.Helpers
  alias Engine.ObservedHeadways

  describe "GenServer initialization" do
    test "has reasonable starting state" do
      {:ok, _pid} =
        ObservedHeadways.start_link(
          gen_server_name: :new_observed_headways_server,
          ets_table_name: :initial_state_table
        )

      expected_recent_headways = %{
        "alewife" => [3600],
        "ashmont" => [3600],
        "bowdoin" => [3600],
        "braintree" => [3600],
        "forest_hills" => [3600],
        "oak_grove" => [3600],
        "wonderland" => [3600]
      }

      expected_stop_ids_to_terminal_ids = %{
        "70082" => ["ashmont", "braintree"],
        "70083" => ["alewife"],
        "70084" => ["ashmont", "braintree"],
        "70086" => ["ashmont"],
        "70088" => ["ashmont"],
        "70090" => ["ashmont"],
        "70096" => ["braintree"]
      }

      actual_recent_headways = :ets.lookup_element(:initial_state_table, :recent_headways, 2)

      actual_stop_ids_to_terminal_ids =
        :ets.lookup_element(:initial_state_table, :stop_ids_to_terminal_ids, 2)

      assert actual_recent_headways == expected_recent_headways
      assert actual_stop_ids_to_terminal_ids == expected_stop_ids_to_terminal_ids
    end
  end

  describe "get_headways/1" do
    test "bases min and max on last 5 headways at pertinent terminal" do
      new_table_name =
        update_state(%{
          recent_headways: %{
            "alewife" => [621, 475, 739, 740, 530],
            "ashmont" => [540, 783, 942, 623, 673]
          },
          stop_ids_to_terminal_ids: %{
            "123" => ["alewife"],
            "456" => ["ashmont"],
            "789" => ["alewife"]
          }
        })

      assert ObservedHeadways.get_headways(new_table_name, "123") == {8, 12}
    end

    test "behaves correctly if just one headway recorded" do
      new_table_name =
        update_state(%{
          recent_headways: %{
            "ashmont" => [620]
          },
          stop_ids_to_terminal_ids: %{
            "123" => ["ashmont"]
          }
        })

      assert ObservedHeadways.get_headways(new_table_name, "123") == {10, 10}
    end

    test "bases min and max on most optimistic and pessimistic respectively of last headways when multiple pertinent terminals" do
      new_table_name =
        update_state(%{
          recent_headways: %{
            "ashmont" => [621, 475, 739, 740, 1035],
            "braintree" => [540, 783, 942, 623, 673]
          },
          stop_ids_to_terminal_ids: %{
            "456" => ["ashmont", "braintree"]
          }
        })

      assert ObservedHeadways.get_headways(new_table_name, "456") == {8, 17}
    end

    test "shows spread of 10 minutes maximum" do
      new_table_name =
        update_state(%{
          recent_headways: %{
            "ashmont" => [450, 783, 942, 623, 1130]
          },
          stop_ids_to_terminal_ids: %{
            "456" => ["ashmont"]
          }
        })

      assert ObservedHeadways.get_headways(new_table_name, "456") == {9, 19}
    end

    test "bounds are never lower than 4 minutes" do
      new_table_name =
        update_state(%{
          recent_headways: %{
            "ashmont" => [121, 783, 842, 623, 820],
            "braintree" => [180, 183, 142, 123, 220]
          },
          stop_ids_to_terminal_ids: %{
            "123" => ["ashmont"],
            "456" => ["braintree"]
          }
        })

      assert ObservedHeadways.get_headways(new_table_name, "123") == {4, 14}
      assert ObservedHeadways.get_headways(new_table_name, "456") == {4, 4}
    end

    test "bounds are never higher than 20 minutes" do
      new_table_name =
        update_state(%{
          recent_headways: %{
            "ashmont" => [620, 1200, 842, 623, 920],
            "braintree" => [1300, 1400, 1500, 1600, 1700]
          },
          stop_ids_to_terminal_ids: %{
            "123" => ["ashmont"],
            "456" => ["braintree"]
          }
        })

      assert ObservedHeadways.get_headways(new_table_name, "123") == {10, 20}
      assert ObservedHeadways.get_headways(new_table_name, "456") == {20, 20}
    end
  end

  defmodule FakeHeadwayFetcherHappy do
    def fetch() do
      new_headways = %{
        "alewife" => [1, 4, 9],
        "ashmont" => [2, 3, 5],
        "bowdoin" => [99, 100, 101],
        "braintree" => [31, 41, 519],
        "forest_hills" => [27, 181],
        "oak_grove" => [42, 666],
        "wonderland" => [37]
      }

      {:ok, new_headways}
    end
  end

  defmodule FakeHeadwayFetcherSad do
    def fetch(), do: {:error, "Everything is terrible"}
  end

  describe "headway fetching" do
    test "overwrites old headway information when successful" do
      reassign_env(:observed_headway_fetcher, FakeHeadwayFetcherHappy)

      :table_for_overwrite_test =
        :ets.new(:table_for_overwrite_test, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      {:noreply, :table_for_overwrite_test} =
        ObservedHeadways.handle_info(:fetch_headways, :table_for_overwrite_test)

      assert :ets.lookup_element(:table_for_overwrite_test, :recent_headways, 2) == %{
               "alewife" => [1, 4, 9],
               "ashmont" => [2, 3, 5],
               "bowdoin" => [99, 100, 101],
               "braintree" => [31, 41, 519],
               "forest_hills" => [27, 181],
               "oak_grove" => [42, 666],
               "wonderland" => [37]
             }
    end

    test "does not overwrite old headway information when not successful" do
      reassign_env(:observed_headway_fetcher, FakeHeadwayFetcherSad)

      original_state = :sys.get_state(ObservedHeadways)
      {:noreply, new_state} = ObservedHeadways.handle_info(:fetch_headways, original_state)

      assert new_state == original_state
    end
  end

  defp update_state(new_state) do
    new_table_name = UUID.uuid1() |> String.to_atom()

    ^new_table_name =
      :ets.new(new_table_name, [:set, :protected, :named_table, read_concurrency: true])

    for pair <- new_state do
      :ets.insert(new_table_name, pair)
    end

    :ets.lookup(new_table_name, :recent_headways)
    :ets.lookup(new_table_name, :stop_ids_to_terminal_ids)

    new_table_name
  end
end
