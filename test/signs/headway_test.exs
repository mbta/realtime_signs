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
    bridge_engine: FakeBridgeEngine,
    sign_updater: FakeSignUpdater,
    timer: nil,
    read_sign_period_ms: 30_000
  }

  describe "callback update_content" do
    test "when the sign is disabled, does not send an update" do
      sign = %{@sign | id: "MVAL0"}
      :timer.sleep(1000)

      assert {:noreply,
              %{
                current_content_top: %Content.Message.Empty{},
                current_content_bottom: %Content.Message.Empty{}
              }} = Signs.Headway.handle_info(:update_content, sign)
    end

    test "updates the top and bottom contents" do
      log =
        capture_log([level: :info], fn ->
          {:noreply,
           %{
             timer: timer,
             current_content_top: %Content.Message.Headways.Top{
               headsign: "Chelsea",
               vehicle_type: :bus
             },
             current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
           }} = handle_info(:update_content, @sign)

          refute is_nil(timer)
        end)

      assert log =~ "update_sign called"
    end

    test "when the bottom content does not change, it does not send an update" do
      sign = %{
        @sign
        | current_content_top: %Content.Message.Headways.Top{
            headsign: "Chelsea",
            vehicle_type: :bus
          },
          current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      log =
        capture_log([level: :info], fn ->
          handle_info(:update_content, sign)
        end)

      refute log =~ "update_sign called"
    end

    test "when the first departure is in the future, does not send an update" do
      sign = %{
        @sign
        | current_content_bottom: Content.Message.Empty.new(),
          gtfs_stop_id: "first_departure"
      }

      log =
        capture_log([level: :info], fn ->
          handle_info(:update_content, sign)
        end)

      refute log =~ "update_sign called"
    end

    test "when the first departure is in the future but within the range of the headway, sends an update" do
      sign = %{@sign | gtfs_stop_id: "first_departure_soon"}

      log =
        capture_log([level: :info], fn ->
          handle_info(:update_content, sign)
        end)

      assert log =~ "update_sign called"
    end

    test "if the bridge is down, does not update the sign" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "743",
        headsign: "Chelsea",
        headway_engine: FakeHeadwayEngine,
        bridge_engine: FakeBridgeEngine,
        sign_updater: FakeSignUpdater,
        read_sign_period_ms: 30_000,
        bridge_id: "down",
        timer: nil,
        current_content_top: %Content.Message.Headways.Top{
          headsign: "Chelsea",
          vehicle_type: :bus
        },
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      log =
        capture_log([level: :info], fn ->
          handle_info(:update_content, sign)
        end)

      assert log != "update_sign called"
    end

    test "if the bridge is up, updates the sign and announces it" do
      Process.register(self(), :headway_test_fake_updater_listener)

      sign = %{
        @sign
        | bridge_id: "up",
          current_content_top: %Content.Message.Headways.Top{
            headsign: "Chelsea",
            vehicle_type: :bus
          },
          current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      assert {:noreply,
              %{
                current_content_top: %Content.Message.Bridge.Up{},
                current_content_bottom: %Content.Message.Bridge.Delays{}
              }} = handle_info(:update_content, sign)

      assert_received({:send_audio, {_, %Content.Audio.BridgeIsUp{language: :english}, _, _}})
      assert_received({:send_audio, {_, %Content.Audio.BridgeIsUp{language: :spanish}, _, _}})
    end

    test "if the bridge is up, does not announce it if it's been up and is merely refreshing" do
      Process.register(self(), :headway_test_fake_updater_listener)

      sign = %{
        @sign
        | bridge_id: "up",
          current_content_top: Content.Message.Empty.new(),
          current_content_bottom: Content.Message.Empty.new()
      }

      assert {:noreply,
              %{
                current_content_top: %Content.Message.Bridge.Up{},
                current_content_bottom: %Content.Message.Bridge.Delays{}
              }} = handle_info(:update_content, sign)

      refute_received({:send_audio, {_, %Content.Audio.BridgeIsUp{}, _, _}})
    end

    test "if there is no bridge id, does not update the sign" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "743",
        headsign: "Chelsea",
        headway_engine: FakeHeadwayEngine,
        bridge_engine: FakeBridgeEngine,
        sign_updater: FakeSignUpdater,
        read_sign_period_ms: 30_000,
        timer: nil,
        current_content_top: %Content.Message.Headways.Top{
          headsign: "Chelsea",
          vehicle_type: :bus
        },
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      log =
        capture_log([level: :info], fn ->
          handle_info(:update_content, sign)
        end)

      assert log != "update_sign called"
    end

    test "Messages for buses are passed through correctly" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "743",
        headsign: "Chelsea",
        headway_engine: FakeHeadwayEngine,
        bridge_engine: FakeBridgeEngine,
        sign_updater: FakeSignUpdater,
        read_sign_period_ms: 30_000,
        timer: nil,
        current_content_top: %Content.Message.Headways.Top{
          headsign: "Chelsea",
          vehicle_type: :bus
        },
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Chelsea",
               vehicle_type: :bus
             }
    end

    test "Messages for trolleys are passed through correctly" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "Mattapan",
        headsign: "Ashmont",
        headway_engine: FakeHeadwayEngine,
        bridge_engine: FakeBridgeEngine,
        sign_updater: FakeSignUpdater,
        read_sign_period_ms: 30_000,
        timer: nil,
        current_content_top: %Content.Message.Headways.Top{
          headsign: "Ashmont",
          vehicle_type: :trolley
        },
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Ashmont",
               vehicle_type: :trolley
             }
    end

    test "Messages for trains are passed through correctly" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "Green-D",
        headsign: "Riverside",
        headway_engine: FakeHeadwayEngine,
        bridge_engine: FakeBridgeEngine,
        sign_updater: FakeSignUpdater,
        read_sign_period_ms: 30_000,
        timer: nil,
        current_content_top: %Content.Message.Headways.Top{
          headsign: "Riverside",
          vehicle_type: :train
        },
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Riverside",
               vehicle_type: :train
             }
    end
  end

  describe "read sign callback" do
    test "sends an audio request corresponding to the headway message" do
      Process.register(self(), :headway_test_fake_updater_listener)
      sign = %{@sign | current_content_bottom: %Content.Message.Headways.Bottom{range: {10, 12}}}
      assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:read_sign, sign)

      assert_received(
        {:send_audio,
         {{"ABCD", "n"},
          %Content.Audio.VehiclesToDestination{
            next_trip_mins: 10,
            later_trip_mins: 12,
            language: :english
          }, 5, 120}}
      )

      assert_received(
        {:send_audio,
         {{"ABCD", "n"},
          %Content.Audio.VehiclesToDestination{
            next_trip_mins: 10,
            later_trip_mins: 12,
            language: :spanish
          }, 5, 120}}
      )
    end

    test "does not send audio message if bridge is up" do
      Process.register(self(), :headway_test_fake_updater_listener)
      sign = %{@sign | current_content_bottom: %Content.Message.Bridge.Delays{}}
      assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:read_sign, sign)

      refute_received(
        {:send_audio,
         {{"ABCD", "n"},
          %Content.Audio.VehiclesToDestination{
            next_trip_mins: 10,
            later_trip_mins: 12,
            language: :english
          }, 5, 120}}
      )

      refute_received(
        {:send_audio,
         {{"ABCD", "n"},
          %Content.Audio.VehiclesToDestination{
            next_trip_mins: 10,
            later_trip_mins: 12,
            language: :spanish
          }, 5, 120}}
      )
    end

    test "callback is invoked periodically" do
      Process.register(self(), :headway_test_fake_updater_listener)

      sign = %{
        @sign
        | current_content_bottom: %Content.Message.Headways.Bottom{range: {5, 8}},
          read_sign_period_ms: 100
      }

      {:ok, _pid} = GenServer.start_link(Signs.Headway, sign)

      :timer.sleep(50)

      refute_received(
        {:send_audio,
         {{"ABCD", "n"}, %Content.Audio.VehiclesToDestination{language: :english}, 5, 120}}
      )

      :timer.sleep(100)

      assert_received(
        {:send_audio,
         {{"ABCD", "n"}, %Content.Audio.VehiclesToDestination{language: :english}, 5, 120}}
      )

      :timer.sleep(5)

      refute_received(
        {:send_audio,
         {{"ABCD", "n"}, %Content.Audio.VehiclesToDestination{language: :english}, 5, 120}}
      )

      :timer.sleep(100)

      assert_received(
        {:send_audio,
         {{"ABCD", "n"}, %Content.Audio.VehiclesToDestination{language: :english}, 5, 120}}
      )
    end
  end

  describe "bridge announcement callback" do
    test "reads bridge message if bridge is up" do
      Process.register(self(), :headway_test_fake_updater_listener)
      sign = %{@sign | current_content_top: %Content.Message.Bridge.Up{}}
      {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:bridge_announcement_update, sign)
      assert_received({:send_audio, {_, %Content.Audio.BridgeIsUp{language: :english}, _, _}})
      assert_received({:send_audio, {_, %Content.Audio.BridgeIsUp{language: :spanish}, _, _}})
    end

    test "does not read message is bridge is not up" do
      Process.register(self(), :headway_test_fake_updater_listener)
      sign = %{@sign | current_content_top: %Content.Message.Empty{}}
      {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:bridge_announcement_update, sign)
      refute_received({:send_audio, {_, %Content.Audio.BridgeIsUp{language: :english}, _, _}})
      refute_received({:send_audio, {_, %Content.Audio.BridgeIsUp{language: :spanish}, _, _}})
    end
  end

  test "handles unknown messages" do
    assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:unknown, @sign)
  end
end

defmodule FakeHeadwayEngine do
  def get_headways("first_departure_soon") do
    future_departure = Timex.shift(Timex.now(), minutes: 5)
    {:first_departure, {8, 10}, future_departure}
  end

  def get_headways("first_departure") do
    future_departure = Timex.shift(Timex.now(), minutes: 20)
    {:first_departure, {1, 2}, future_departure}
  end

  def get_headways(_stop_id) do
    {1, 2}
  end
end

defmodule FakeBridgeEngine do
  def status("down") do
    {"Lowered", nil}
  end

  def status("up") do
    {"Raised", 15}
  end

  def status(_) do
    nil
  end
end

defmodule FakeSignUpdater do
  require Logger

  def update_sign(id, line, message, duration, start) do
    Logger.info("update_sign called")
    {id, line, message, duration, start}
  end

  def send_audio(pa_ess_id, msg, priority, timeout) do
    if Process.whereis(:headway_test_fake_updater_listener) do
      send(
        :headway_test_fake_updater_listener,
        {:send_audio, {pa_ess_id, msg, priority, timeout}}
      )
    end

    {:ok, :sent}
  end
end
