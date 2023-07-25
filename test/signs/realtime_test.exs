defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Content.Message.Headways.Top, as: HT
  alias Content.Message.Headways.Bottom, as: HB

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakePassthroughPredictions do
    def for_stop("1", 0) do
      [
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 4,
          destination_stop_id: "70105",
          seconds_until_arrival: nil,
          seconds_until_departure: nil,
          seconds_until_passthrough: 30,
          trip_id: "123"
        }
      ]
    end

    def for_stop(_stop_id, _direction_id), do: []
  end

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 5}
    def display_headways?(_stop_ids, _time, _buffer), do: true
  end

  defmodule FakeConfigEngine do
    def sign_config(_sign_id), do: :auto

    def headway_config(_group, _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 11, range_high: 13}
    end
  end

  defmodule FakeUpdater do
    def update_sign(id, top_msg, bottom_msg, duration, start, sign_id) do
      send(self(), {:update_sign, id, top_msg, bottom_msg, duration, start, sign_id})
    end

    def send_audio(id, audio, priority, timeout, sign_id) do
      send(self(), {:send_audio, id, audio, priority, timeout, sign_id})
    end
  end

  defmodule FakeAlerts do
    def max_stop_status(["suspended"], _routes), do: :suspension_closed_station
    def max_stop_status(["suspended_transfer"], _routes), do: :suspension_transfer_station
    def max_stop_status(["shuttles"], _routes), do: :shuttles_closed_station
    def max_stop_status(["closure"], _routes), do: :station_closure
    def max_stop_status(_stops, ["Green-B"]), do: :alert_along_route
    def max_stop_status(_stops, _routes), do: :none
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: %{
      sources: [@src],
      headway_group: "headway_group",
      headway_destination: :southbound
    },
    current_content_top: %HT{destination: :southbound, vehicle_type: :train},
    current_content_bottom: %HB{range: {1, 5}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    config_engine: FakeConfigEngine,
    alerts_engine: FakeAlerts,
    sign_updater: FakeUpdater,
    last_update: Timex.now(),
    tick_read: 1,
    read_period_seconds: 100
  }

  describe "run loop" do
    test "starts up and logs unknown messages" do
      assert {:ok, pid} = GenServer.start_link(Signs.Realtime, @sign)

      log =
        capture_log([level: :warn], fn ->
          send(pid, :foo)
          Process.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown_message"
    end

    test "decrements ticks and doesn't send audio or text when sign is not expired" do
      sign = %{
        @sign
        | current_content_bottom: %HB{range: {11, 13}}
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)
      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_sign, _, _, _, _, _})
      assert sign.tick_read == 0
    end

    test "expires content on both lines when tick is zero" do
      sign = %{
        @sign
        | last_update: Timex.shift(Timex.now(), seconds: -200),
          current_content_top: %HT{destination: :southbound, vehicle_type: :train},
          current_content_bottom: %HB{range: {11, 13}}
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)

      assert_received(
        {:update_sign, _id, %HT{destination: :southbound, vehicle_type: :train},
         %HB{range: {11, 13}}, _dur, _start, _sign_id}
      )

      refute_received({:send_audio, _, _, _, _})
    end

    test "announces train passing through station" do
      sign = %{
        @sign
        | prediction_engine: FakePassthroughPredictions
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)
      assert sign.announced_passthroughs == ["123"]
      assert_received({:send_audio, _, [%Content.Audio.Passthrough{}], _, _, _})
    end
  end

  describe "decrement_ticks/1" do
    test "decrements all the ticks when all of them dont need to be reset" do
      sign = %{
        @sign
        | tick_read: 100
      }

      sign = Signs.Realtime.decrement_ticks(sign)

      assert sign.tick_read == 99
    end
  end
end
