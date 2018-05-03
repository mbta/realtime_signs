defmodule Signs.HeadwayTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Signs.Headway

  @sign %Signs.Headway{
    id: "SIGN",
    pa_ess_id: {"ABCD", "n"},
    gtfs_stop_id: "123",
    route_id: "743",
    headsign: "Chelsea",
    headway_engine: FakeHeadwayEngine,
    sign_updater: FakeSignUpdater,
    timer: nil,
    read_sign_period_ms: 30_000,
  }

  describe "callback update_content" do
    test "updates the top and bottom contents" do
      log = capture_log [level: :info], fn ->
        assert handle_info(:update_content, @sign) == {:noreply, %{@sign | current_content_top: %Content.Message.Headways.Top{headsign: "Chelsea", vehicle_type: :bus}, current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}}}
      end
      assert log =~ "update_sign called"
    end

    test "when the bottom content does not change, it does not send an update" do
      sign = %{@sign |
        current_content_top: %Content.Message.Headways.Top{headsign: "Chelsea", vehicle_type: :bus},
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      log = capture_log [level: :info], fn ->
        handle_info(:update_content, sign)
      end
      refute log =~ "update_sign called"
    end

    test "when the first departure is in the future, does not send an update" do
      sign = %{@sign | gtfs_stop_id: "first_departure"}

      log = capture_log [level: :info], fn ->
        handle_info(:update_content, sign)
      end
      refute log =~ "update_sign called"
    end

    test "when the first departure is in the future but within the range of the headway, sends an update" do
      sign = %{@sign | gtfs_stop_id: "first_departure_soon"}

      log = capture_log [level: :info], fn ->
        handle_info(:update_content, sign)
      end
      assert log =~ "update_sign called"
    end
  end

  describe "read sign callback" do
    test "sends an audio request corresponding to the headway message" do
      Process.register(self(), :headway_test_fake_updater_listener)
      sign = %{@sign | current_content_bottom: %Content.Message.Headways.Bottom{range: {10, 12}}}
      assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:read_sign, sign)
      assert_received({:send_audio, {{"ABCD", "n"}, %Content.Audio.BusesToDestination{next_bus_mins: 10, later_bus_mins: 12, language: :english}, 5, 120}})
      assert_received({:send_audio, {{"ABCD", "n"}, %Content.Audio.BusesToDestination{next_bus_mins: 10, later_bus_mins: 12, language: :spanish}, 5, 120}})
    end

    test "callback is invoked periodically" do
      Process.register(self(), :headway_test_fake_updater_listener)
      sign = %{@sign |
        current_content_bottom: %Content.Message.Headways.Bottom{range: {5, 8}},
        read_sign_period_ms: 100,
      }

      {:ok, _pid} = GenServer.start_link(Signs.Headway, sign)

      :timer.sleep(50)
      refute_received({:send_audio, {{"ABCD", "n"}, %Content.Audio.BusesToDestination{language: :english}, 5, 120}})
      :timer.sleep(100)
      assert_received({:send_audio, {{"ABCD", "n"}, %Content.Audio.BusesToDestination{language: :english}, 5, 120}})
      :timer.sleep(5)
      refute_received({:send_audio, {{"ABCD", "n"}, %Content.Audio.BusesToDestination{language: :english}, 5, 120}})
      :timer.sleep(100)
      assert_received({:send_audio, {{"ABCD", "n"}, %Content.Audio.BusesToDestination{language: :english}, 5, 120}})
    end
  end
end

defmodule FakeHeadwayEngine do
  def get_headways("first_departure_soon") do
    future_departure = Timex.shift(Timex.now(), minutes: 5)
    {:first_departure, {8, 10}, future_departure}
  end
  def get_headways("first_departure") do
    future_departure = Timex.shift(Timex.now(), minutes: 10)
    {:first_departure, {1, 2}, future_departure}
  end
  def get_headways(_stop_id) do
    {1, 2}
  end
end

defmodule FakeSignUpdater do
  require Logger
  def update_sign(id, line, message, duration, start) do
    Logger.info "update_sign called"
    {id, line, message, duration, start}
  end

  def send_audio(pa_ess_id, msg, priority, timeout) do
    if Process.whereis(:headway_test_fake_updater_listener) do
      send(:headway_test_fake_updater_listener, {:send_audio, {pa_ess_id, msg, priority, timeout}})
    end
    {:ok, :sent}
  end
end
