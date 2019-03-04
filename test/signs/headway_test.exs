defmodule Signs.HeadwayTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Signs.Headway

  defmodule FakeHeadwayEngine do
    def get_headways("first_departure_soon") do
      future_departure = Timex.shift(Timex.now(), minutes: 5)
      {:first_departure, {8, 10}, future_departure}
    end

    def get_headways("first_departure") do
      future_departure = Timex.shift(Timex.now(), minutes: 20)
      {:first_departure, {1, 2}, future_departure}
    end

    def get_headways("none") do
      :none
    end

    def get_headways("nil_nil") do
      {nil, nil}
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

  defmodule FakeAlertsEngine do
    def max_stop_status(["suspended"], _routes), do: :suspension_closed_station
    def max_stop_status(["suspended_transfer"], _routes), do: :suspension_transfer_station
    def max_stop_status(["shuttles"], _routes), do: :shuttles_closed_station
    def max_stop_status(["closure"], _routes), do: :station_closure
    def max_stop_status(_stops, ["Green-B"]), do: :something
    def max_stop_status(_stops, _routes), do: :none
  end

  defmodule FakeConfigEngine do
    @spec enabled?(String.t()) :: boolean()
    def enabled?("disabled_sign") do
      false
    end

    def enabled?(_) do
      true
    end

    @spec custom_text(String.t()) :: {String.t(), String.t()} | nil
    def custom_text("custom_text_test") do
      {"Test message", "Please ignore"}
    end

    def custom_text(_) do
      nil
    end
  end

  @sign %Signs.Headway{
    id: "SIGN",
    pa_ess_id: {"ABCD", "n"},
    gtfs_stop_id: "123",
    route_id: "743",
    headsign: "Chelsea",
    headway_engine: FakeHeadwayEngine,
    bridge_engine: FakeBridgeEngine,
    alerts_engine: FakeAlertsEngine,
    config_engine: FakeConfigEngine,
    sign_updater: FakeSignUpdater,
    timer: nil,
    read_sign_period_ms: 30_000
  }

  describe "callback update_content" do
    test "when the sign is disabled, does not send an update" do
      sign = %{@sign | id: "disabled_sign"}

      assert {:noreply,
              %{
                current_content_top: %Content.Message.Empty{},
                current_content_bottom: %Content.Message.Empty{}
              }} = Signs.Headway.handle_info(:update_content, sign)
    end

    test "displays custom text when present" do
      sign = %{@sign | id: "custom_text_test"}

      assert {:noreply,
              %{
                current_content_top: %Content.Message.Custom{message: "Test message"},
                current_content_bottom: %Content.Message.Custom{message: "Please ignore"}
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

    test "when the first departure is in the future outside the range of the headway, blanks the sign" do
      sign = %{
        @sign
        | current_content_bottom: Content.Message.Empty.new(),
          gtfs_stop_id: "first_departure"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Empty{}
      assert sign.current_content_bottom == %Content.Message.Empty{}
    end

    test "when the first departure is in the future but within the range of the headway, puts headway info on sign" do
      sign = %{@sign | gtfs_stop_id: "first_departure_soon"}

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Chelsea",
               vehicle_type: :bus
             }

      assert sign.current_content_bottom == %Content.Message.Headways.Bottom{range: {8, 10}}
    end

    test "when the headway engine returns :none, blanks the sign" do
      sign = %{@sign | gtfs_stop_id: "none"}

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Empty{}
      assert sign.current_content_bottom == %Content.Message.Empty{}
    end

    test "when the headway engine returns {nil, nil}, blanks the sign" do
      sign = %{@sign | gtfs_stop_id: "none"}

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Empty{}
      assert sign.current_content_bottom == %Content.Message.Empty{}
    end

    test "if the bridge is down, does not update the sign" do
      sign = %{
        @sign
        | pa_ess_id: "1",
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
      sign = %{
        @sign
        | pa_ess_id: "1",
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
      sign = %{
        @sign
        | route_id: "743",
          headsign: "Chelsea"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Chelsea",
               vehicle_type: :bus
             }
    end

    test "Messages for trolleys are passed through correctly" do
      sign = %{
        @sign
        | route_id: "Mattapan",
          headsign: "Ashmont"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Ashmont",
               vehicle_type: :trolley
             }
    end

    test "Messages for trains are passed through correctly" do
      sign = %{
        @sign
        | route_id: "Green-D",
          headsign: "Riverside"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Headways.Top{
               headsign: "Riverside",
               vehicle_type: :train
             }
    end

    test "if the station is closed from a suspension, it displays that" do
      sign = %{
        @sign
        | current_content_top: Content.Message.Empty.new(),
          current_content_bottom: Content.Message.Empty.new(),
          gtfs_stop_id: "suspended"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Alert.NoService{mode: :train}
      assert sign.current_content_bottom == %Content.Message.Empty{}
    end

    test "if the station is closed from a suspension but its the transfer station, it displays nothing" do
      sign = %{
        @sign
        | current_content_top: Content.Message.Empty.new(),
          current_content_bottom: Content.Message.Empty.new(),
          gtfs_stop_id: "suspended_transfer"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Empty{}
      assert sign.current_content_bottom == %Content.Message.Empty{}
    end

    test "if the station is closed due to shuttle buses, it displays that" do
      sign = %{
        @sign
        | current_content_top: Content.Message.Empty.new(),
          current_content_bottom: Content.Message.Empty.new(),
          gtfs_stop_id: "shuttles"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Alert.NoService{mode: :none}
      assert sign.current_content_bottom == %Content.Message.Alert.UseShuttleBus{}
    end

    test "if the station is closed, it displays that" do
      sign = %{
        @sign
        | current_content_top: Content.Message.Empty.new(),
          current_content_bottom: Content.Message.Empty.new(),
          gtfs_stop_id: "closure"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_top == %Content.Message.Alert.NoService{mode: :train}
      assert sign.current_content_bottom == %Content.Message.Empty{}
    end

    test "if the line has an alert at a different station, the headways are increased" do
      sign = %{
        @sign
        | current_content_top: Content.Message.Empty.new(),
          current_content_bottom: Content.Message.Empty.new(),
          route_id: "Green-B"
      }

      {:noreply, sign} = handle_info(:update_content, sign)

      assert sign.current_content_bottom == %Content.Message.Headways.Bottom{range: {4, 5}}
    end
  end

  describe "read sign callback" do
    test "sends an audio request corresponding to the headway message" do
      Process.register(self(), :headway_test_fake_updater_listener)

      sign = %{
        @sign
        | current_content_bottom: %Content.Message.Headways.Bottom{range: {10, 12}},
          current_content_top: %Content.Message.Headways.Top{headsign: "Chelsea"}
      }

      assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:read_sign, sign)

      assert_received(
        {:send_audio,
         {{"ABCD", "n"},
          {%Content.Audio.VehiclesToDestination{
             next_trip_mins: 10,
             later_trip_mins: 12,
             language: :english
           },
           %Content.Audio.VehiclesToDestination{
             next_trip_mins: 10,
             later_trip_mins: 12,
             language: :spanish
           }}, 5, 120}}
      )
    end

    test "sends an audio request corresponding to station closure due to suspesnion alert" do
      Process.register(self(), :headway_test_fake_updater_listener)

      sign = %{
        @sign
        | current_content_top: %Content.Message.Alert.NoService{mode: :none},
          current_content_bottom: %Content.Message.Empty{}
      }

      assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:read_sign, sign)

      assert_received(
        {:send_audio,
         {{"ABCD", "n"},
          %Content.Audio.Closure{
            alert: :suspension_closed_station
          }, 5, 120}}
      )
    end

    test "does not send audio at transfer stop of a suspension alert" do
      Process.register(self(), :headway_test_fake_updater_listener)

      sign = %{
        @sign
        | current_content_top: %Content.Message.Alert.NoService{mode: :none},
          current_content_bottom: %Content.Message.Empty{},
          gtfs_stop_id: "suspension_transfer"
      }

      assert {:noreply, %Signs.Headway{}} = Signs.Headway.handle_info(:update_content, sign)

      refute_received({:send_audio, {{"ABCD", "n"}, _}})
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
          current_content_top: %Content.Message.Headways.Top{headsign: "Chelsea"},
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
         {{"ABCD", "n"},
          {%Content.Audio.VehiclesToDestination{language: :english},
           %Content.Audio.VehiclesToDestination{language: :spanish}}, 5, 120}}
      )

      :timer.sleep(5)

      refute_received(
        {:send_audio,
         {{"ABCD", "n"}, %Content.Audio.VehiclesToDestination{language: :english}, 5, 120}}
      )

      :timer.sleep(100)

      assert_received(
        {:send_audio,
         {{"ABCD", "n"},
          {%Content.Audio.VehiclesToDestination{language: :english},
           %Content.Audio.VehiclesToDestination{language: :spanish}}, 5, 120}}
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
