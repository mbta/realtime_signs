defmodule Engine.ObservedHeadwaysTest do
  use ExUnit.Case
  import Test.Support.Helpers
  alias Engine.ObservedHeadways

  describe "GenServer initialization" do
    test "has reasonable starting state" do
      {:ok, pid} = ObservedHeadways.start_link(gen_server_name: :new_observed_headways_server)

      assert :sys.get_state(pid) == %ObservedHeadways{
               recent_headways: %{
                 "alewife" => [3600],
                 "ashmont" => [3600],
                 "bowdoin" => [3600],
                 "braintree" => [3600],
                 "forest_hills" => [3600],
                 "oak_grove" => [3600],
                 "wonderland" => [3600]
               },
               stops: %{
                 "70082" => ["ashmont", "braintree"],
                 "70083" => ["alewife"],
                 "70084" => ["ashmont", "braintree"],
                 "70086" => ["ashmont"],
                 "70088" => ["ashmont"],
                 "70090" => ["ashmont"],
                 "70096" => ["braintree"]
               }
             }
    end
  end

  describe "get_headways/1" do
    setup do
      original_state = :sys.get_state(ObservedHeadways)
      on_exit(fn -> :sys.replace_state(ObservedHeadways, fn _ -> original_state end) end)
    end

    test "bases min and max on last 5 headways at pertinent terminal" do
      :sys.replace_state(ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "alewife" => [621, 475, 739, 740, 530],
            "ashmont" => [540, 783, 942, 623, 673]
          },
          stops: %{
            "123" => ["alewife"],
            "456" => ["ashmont"],
            "789" => ["alewife"]
          }
        }
      end)

      assert ObservedHeadways.get_headways("123") == {8, 12}
    end

    test "behaves correctly if just one headway recorded" do
      :sys.replace_state(ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [620]
          },
          stops: %{
            "123" => ["ashmont"]
          }
        }
      end)

      assert ObservedHeadways.get_headways("123") == {10, 10}
    end

    test "bases min and max on most pessimistic of last headways when multiple pertinent terminals" do
      :sys.replace_state(ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [621, 475, 739, 740, 1035],
            "braintree" => [540, 783, 942, 623, 673]
          },
          stops: %{
            "456" => ["ashmont", "braintree"]
          }
        }
      end)

      assert ObservedHeadways.get_headways("456") == {9, 17}
    end

    test "shows spread of 10 minutes maximum" do
      :sys.replace_state(ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [450, 783, 942, 623, 1130]
          },
          stops: %{
            "456" => ["ashmont"]
          }
        }
      end)

      assert ObservedHeadways.get_headways("456") == {9, 19}
    end

    test "bounds are never lower than 6 minutes" do
      :sys.replace_state(ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [300, 783, 842, 623, 920],
            "braintree" => [280, 183, 242, 123, 320]
          },
          stops: %{
            "123" => ["ashmont"],
            "456" => ["braintree"]
          }
        }
      end)

      assert ObservedHeadways.get_headways("123") == {6, 15}
      assert ObservedHeadways.get_headways("456") == {6, 6}
    end

    test "bounds are never higher than 20 minutes" do
      :sys.replace_state(ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [620, 1200, 842, 623, 920],
            "braintree" => [1300, 1400, 1500, 1600, 1700]
          },
          stops: %{
            "123" => ["ashmont"],
            "456" => ["braintree"]
          }
        }
      end)

      assert ObservedHeadways.get_headways("123") == {10, 20}
      assert ObservedHeadways.get_headways("456") == {20, 20}
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
    def fetch(), do: :error
  end

  describe "headway fetching" do
    test "overwrites old headway information when successful" do
      reassign_env(:observed_headway_fetcher, FakeHeadwayFetcherHappy)

      {:noreply, new_state} =
        ObservedHeadways.handle_info(:fetch_headways, :sys.get_state(ObservedHeadways))

      assert new_state.recent_headways == %{
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
end
