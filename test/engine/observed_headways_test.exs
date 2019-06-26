defmodule Engine.ObservedHeadwaysTest do
  use ExUnit.Case

  describe "GenServer initialization" do
    test "has reasonable starting state" do
      {:ok, pid} =
        Engine.ObservedHeadways.start_link(gen_server_name: :new_observed_headways_server)

      assert :sys.get_state(pid) == %Engine.ObservedHeadways{
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
                 "70085" => ["alewife"],
                 "70086" => ["ashmont"],
                 "70087" => ["alewife"],
                 "70088" => ["ashmont"],
                 "70089" => ["alewife"],
                 "70090" => ["ashmont"],
                 "70095" => ["alewife"],
                 "70096" => ["braintree"]
               }
             }
    end
  end

  describe "get_headways/1" do
    setup do
      original_state = :sys.get_state(Engine.ObservedHeadways)
      on_exit(fn -> :sys.replace_state(Engine.ObservedHeadways, fn _ -> original_state end) end)
    end

    test "bases min and max on last 5 headways at pertinent terminal" do
      :sys.replace_state(Engine.ObservedHeadways, fn _ ->
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

      assert Engine.ObservedHeadways.get_headways("123") == {8, 12}
    end

    test "behaves correctly if just one headway recorded" do
      :sys.replace_state(Engine.ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [620]
          },
          stops: %{
            "123" => ["ashmont"]
          }
        }
      end)

      assert Engine.ObservedHeadways.get_headways("123") == {10, 10}
    end

    test "bases min and max on most pessimistic of last headways when multiple pertinent terminals" do
      :sys.replace_state(Engine.ObservedHeadways, fn _ ->
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

      assert Engine.ObservedHeadways.get_headways("456") == {9, 17}
    end

    test "shows spread of 10 minutes maximum" do
      :sys.replace_state(Engine.ObservedHeadways, fn _ ->
        %{
          recent_headways: %{
            "ashmont" => [450, 783, 942, 623, 1130]
          },
          stops: %{
            "456" => ["ashmont"]
          }
        }
      end)

      assert Engine.ObservedHeadways.get_headways("456") == {9, 19}
    end

    test "bounds are never lower than 6 minutes" do
      :sys.replace_state(Engine.ObservedHeadways, fn _ ->
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

      assert Engine.ObservedHeadways.get_headways("123") == {6, 15}
      assert Engine.ObservedHeadways.get_headways("456") == {6, 6}
    end

    test "bounds are never higher than 20 minutes" do
      :sys.replace_state(Engine.ObservedHeadways, fn _ ->
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

      assert Engine.ObservedHeadways.get_headways("123") == {10, 20}
      assert Engine.ObservedHeadways.get_headways("456") == {20, 20}
    end
  end
end
