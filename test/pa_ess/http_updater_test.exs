defmodule Fake.MessageQueue do
  def get_message do
    {:update_sign, [{"SBOX", "c"}, "", "", 60, :now, []]}
  end
end

defmodule PaEss.HttpUpdaterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule FakePoster do
    def post(_, q, _, _) do
      send(self(), {:post, q})
      {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  describe "process/2" do
    test "Returns an error if HTTP response code is not 2XX" do
      state = make_state()

      assert {:error, :bad_status} ==
               PaEss.HttpUpdater.process(
                 {:update_sign, [{"bad_sign", "n"}, "top", "bottom", 60, 1234, []]},
                 state
               )
    end

    test "Posts both lines of the sign at the same time" do
      state = make_state()

      log =
        capture_log(fn ->
          assert {:ok, :sent} ==
                   PaEss.HttpUpdater.process(
                     {:update_sign, [{"ABCD", "n"}, "top", "bottom", 60, :now, []]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      assert log =~ ~r" signs_ui_ms=\d+"
    end

    test "Returns error if HTTP request fails when updating both lines, doesn't send to Signs UI" do
      state = make_state()

      log =
        capture_log([level: :info], fn ->
          assert {:error, :post_error} ==
                   PaEss.HttpUpdater.process(
                     {:update_sign, [{"timeout", "n"}, "top", "bottom", 60, :now, []]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      assert log =~ ~r" signs_ui_ms=0"
    end

    test "replies with {:ok, :sent} when successful" do
      state = make_state()

      assert PaEss.HttpUpdater.process(
               {:update_sign, [{"SBOX", "c"}, "", "", 60, :now, []]},
               state
             ) == {:ok, :sent}
    end

    test "replies with {:ok, :no_audio} when to_params returns nil" do
      state = make_state()

      assert {:ok, :no_audio} ==
               PaEss.HttpUpdater.process(
                 {:send_audio, [{"GKEN", ["m"]}, [nil], 5, 60, [[]]]},
                 state
               )
    end
  end

  describe "send_audio/4" do
    test "Buses to Chelsea" do
      state = make_state()

      audio = {:canned, {"133", ["5508", "5512"], :audio}}

      log =
        capture_log(fn ->
          assert {:ok, :sent} ==
                   PaEss.HttpUpdater.process(
                     {:send_audio, [{"SBOX", ["c"]}, [audio], 5, 60, [[]]]},
                     state
                   )
        end)

      assert log =~ ~r"arinc_ms=\d+"
    end

    test "sends custom audio messages" do
      state = make_state()

      audio = {:ad_hoc, {"Custom Message", :audio}}

      log =
        capture_log(fn ->
          assert {:ok, :sent} ==
                   PaEss.HttpUpdater.process(
                     {:send_audio, [{"MCAP", ["n"]}, [audio], 5, 60, [[]]]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      assert log =~ "send_custom_audio"
    end

    test "sends custom audio messages with replacements" do
      state = make_state()

      audio = {:ad_hoc, {"Custom OL Message", :audio}}

      log =
        capture_log(fn ->
          assert {:ok, :sent} =
                   PaEss.HttpUpdater.process(
                     {:send_audio, [{"MCAP", ["n"]}, [audio], 5, 60, [[]]]},
                     state
                   )
        end)

      assert log =~ "send_custom_audio"
      assert log =~ "Custom+Orange+Line+Message"
    end

    test "can send two audio messages" do
      state = make_state(%{http_poster: FakePoster})

      audio1 = {:canned, {"msg1", ["4016"], :audio}}
      audio2 = {:canned, {"msg2", ["4021"], :audio}}

      PaEss.HttpUpdater.process(
        {:send_audio, [{"RPRK", ["s"]}, [audio1, audio2], 5, 60, [[], []]]},
        state
      )

      assert_received {:post, q1}
      assert_received {:post, _}
      assert_received {:post, q2}
      assert q1 =~ "var=4016"
      assert q2 =~ "var=4021"
    end
  end

  test "can send to multiple zones at once" do
    state = make_state(%{http_poster: FakePoster})

    audio = {:canned, {"msg", [], :audio}}

    PaEss.HttpUpdater.process(
      {:send_audio, [{"RPRK", ["m", "s", "c"]}, [audio], 5, 60, [[]]]},
      state
    )

    assert_received {:post, q}
    assert q =~ "sta=RPRK110100"
  end

  test "handle_info pulls from queue" do
    state = make_state(%{queue_mod: Fake.MessageQueue})
    {response, _} = PaEss.HttpUpdater.handle_info(:check_queue, state)

    assert response == :noreply
  end

  describe "to_command/5" do
    test "handles messages that are single string" do
      assert PaEss.HttpUpdater.to_command("Wonderland   2 min", 55, :now, "n", 1) ==
               "e55~n1-\"Wonderland   2 min\""
    end

    test "handles messages that paginate" do
      msg = [{"Ashmont    Stopped", 6}, {"Ashmont    3 stops", 6}, {"Ashmont       away", 6}]

      assert PaEss.HttpUpdater.to_command(msg, 55, :now, "n", 1) ==
               "e55~n1-\"Ashmont       away\".5-\"Ashmont    Stopped\".5-\"Ashmont    3 stops\".5"
    end
  end

  describe "test uids" do
    test "internal counter increments and timestamp does not change" do
      state = make_state(%{queue_mod: Fake.MessageQueue})

      {response, new_state} = PaEss.HttpUpdater.handle_info(:check_queue, state)
      assert response == :noreply
      assert new_state.internal_counter > state.internal_counter
      assert new_state.timestamp == state.timestamp
    end

    test "internal counter resets and timestamp does change" do
      state = make_state(%{queue_mod: Fake.MessageQueue, internal_counter: 15})

      Process.sleep(500)
      {response, new_state} = PaEss.HttpUpdater.handle_info(:check_queue, state)

      assert response == :noreply
      assert new_state.internal_counter == 0
      assert new_state.timestamp != state.timestamp
    end
  end

  defp make_state(init \\ %{}) do
    Map.merge(
      %{
        http_poster: Fake.HTTPoison,
        updater_index: 1,
        internal_counter: 0,
        timestamp: div(System.system_time(:millisecond), 500),
        avg_ms_between_sends: 100
      },
      init
    )
  end
end
