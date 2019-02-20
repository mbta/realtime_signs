defmodule Signs.Utilities.AudioTest do
  use ExUnit.Case, async: true

  alias Content.Message
  alias Content.Audio

  import Signs.Utilities.Audio

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    headway_direction_name: "Southbound",
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[@src]},
    current_content_top: {nil, %Content.Message.Empty{}},
    current_content_bottom: {nil, %Content.Message.Empty{}},
    prediction_engine: nil,
    headway_engine: nil,
    sign_updater: nil,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "from_sign/1" do
    test "Countdowns when headsigns are different" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Braintree", minutes: 4}}
      }

      assert {{
                %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
                %Audio.NextTrainCountdown{destination: :braintree, minutes: 4}
              }, ^sign} = from_sign(sign)
    end

    test "Countdowns don't say second line if same headsign" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 4}}
      }

      assert {
               %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
               ^sign
             } = from_sign(sign)
    end

    test "Countdowns use departs or arrives depending if source is terminal" do
      src = %{@src | terminal?: false}

      sign = %{
        @sign
        | current_content_top: {src, %Message.Predictions{headsign: "Ashmont", minutes: 2}}
      }

      assert {%Audio.NextTrainCountdown{verb: :arrives}, ^sign} = from_sign(sign)

      src = %{@src | terminal?: true}

      sign = %{
        @sign
        | current_content_top: {src, %Message.Predictions{headsign: "Ashmont", minutes: 2}}
      }

      assert {%Audio.NextTrainCountdown{verb: :departs}, ^sign} = from_sign(sign)
    end

    test "Countdowns without minutes just return nil" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Alewife", minutes: nil}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Alewife", minutes: nil}}
      }

      assert {nil, ^sign} = from_sign(sign)
    end

    test "Headway messages" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Headways.Top{headsign: "Alewife"}},
          current_content_bottom: {@src, %Message.Headways.Bottom{range: {1, 3}}}
      }

      assert {
               %Audio.VehiclesToDestination{
                 language: :english,
                 destination: :alewife,
                 next_trip_mins: 1,
                 later_trip_mins: 3
               },
               ^sign
             } = from_sign(sign)
    end

    test "Headways in Spanish, too, if available" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Headways.Top{headsign: "Chelsea"}},
          current_content_bottom: {@src, %Message.Headways.Bottom{range: {1, 3}}}
      }

      assert {{
                %Audio.VehiclesToDestination{language: :english},
                %Audio.VehiclesToDestination{language: :spanish}
              }, ^sign} = from_sign(sign)
    end

    test "Stopped train message" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      }

      assert {
               %Audio.StoppedTrain{destination: :alewife, stops_away: 2},
               ^sign
             } = from_sign(sign)
    end

    test "Custom text" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Custom{line: :top, message: "Custom Top"}},
          current_content_bottom: {@src, %Message.Custom{line: :bottom, message: "Custom Bottom"}}
      }

      assert {
               %Audio.Custom{message: "Custom Top Custom Bottom"},
               ^sign
             } = from_sign(sign)
    end

    test "Station closure" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Alert.NoService{mode: :train}},
          current_content_bottom: {@src, %Message.Alert.UseShuttleBus{}}
      }

      assert {
               %Audio.Closure{alert: :shuttles_closed_station},
               ^sign
             } = from_sign(sign)
    end
  end
end
