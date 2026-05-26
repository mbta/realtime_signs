defmodule Signs.Utilities.MessagesTest do
  use ExUnit.Case

  require Signs.Utilities.Messages

  @midnight DateTime.new!(~D[2023-01-01], ~T[12:00:00], "America/New_York")
  def fake_time_fn, do: @midnight

  describe "get_messages/2" do
    setup do
      source_config = %Signs.Utilities.SourceConfig{
        stop_id: "1",
        direction_id: 0,
        routes: ["Red"],
        announce_arriving?: true,
        announce_boarding?: false
      }

      %{
        sign: %Signs.Realtime{
          id: "sign_id",
          pa_ess_loc: "TEST",
          scu_id: "TESTSCU001",
          text_zone: "x",
          audio_zones: ["x"],
          source_config: %{
            terminal?: false,
            sources: [source_config],
            headway_group: "headway_group",
            headway_destination: :southbound
          },
          current_content_top: "Southbound trains",
          current_content_bottom: "Every 11 to 13 min",
          current_time_fn: &Signs.Utilities.MessagesTest.fake_time_fn/0,
          last_update: @midnight,
          tick_read: 1,
          read_period_seconds: 100,
          pa_message_schedules: %{},
          last_message_log_time: @midnight
        },
        sign_context: %Signs.Utilities.SignContext{
          sign_config: :auto,
          current_time: @midnight,
          config_contexts: [
            %Signs.Utilities.SignContext.ConfigContext{
              config: %{
                terminal?: false,
                sources: [source_config],
                headway_group: "headway_group",
                headway_destination: :southbound
              },
              predictions: [
                %Predictions.Prediction{
                  stop_id: "1",
                  seconds_until_arrival: nil,
                  seconds_until_departure: nil,
                  direction_id: 0,
                  schedule_relationship: nil,
                  route_id: "route_id",
                  trip_id: "123",
                  destination_stop_id: "destination_stop_id",
                  stopped_at_predicted_stop?: false,
                  boarding_status: nil,
                  revenue_trip?: true,
                  vehicle_id: "v1",
                  multi_carriage_details: nil,
                  type: :mid_trip
                }
              ],
              alert_status: :none,
              headways: nil,
              first_scheduled_departure: DateTime.shift(@midnight, hour: -1),
              last_scheduled_departure: DateTime.shift(@midnight, hour: 1),
              most_recent_departure: @midnight,
              service_ended?: false
            }
          ]
        }
      }
    end

    test "returns an empty message when sign is in the overnight period", %{
      sign: sign,
      sign_context: sign_context
    } do
      sign_context = %{
        sign_context
        | sign_config: {:static_text, {"This is line 1", "This is line 2"}},
          current_time: DateTime.shift(@midnight, hour: 2)
      }

      assert [%Message.Empty{}] ==
               Signs.Utilities.Messages.get_messages(
                 sign,
                 sign_context
               )
    end

    test "returns a custom message containing two lines of text", %{
      sign: sign,
      sign_context: sign_context
    } do
      sign_context = %{
        sign_context
        | sign_config: {:static_text, {"This is line 1", "This is line 2"}}
      }

      assert [%Message.Custom{top: "This is line 1", bottom: "This is line 2"}] ==
               Signs.Utilities.Messages.get_messages(
                 sign,
                 sign_context
               )
    end

    test "returns an empty message when sign is off", %{
      sign: sign,
      sign_context: sign_context
    } do
      sign_context = %{
        sign_context
        | sign_config: :off
      }

      assert [%Message.Empty{}] ==
               Signs.Utilities.Messages.get_messages(
                 sign,
                 sign_context
               )
    end

    test "returns a service ended message", %{
      sign: sign,
      sign_context: sign_context
    } do
      sign_context =
        put_in(
          sign_context,
          [Access.key!(:config_contexts), Access.at(0), Access.key!(:service_ended?)],
          true
        )

      assert [%Message.ServiceEnded{destination: :southbound, route: "Red"}] =
               Signs.Utilities.Messages.get_messages(
                 sign,
                 sign_context
               )
    end

    test "returns a first train message", %{
      sign: sign,
      sign_context: sign_context
    } do
      now = DateTime.new!(~D[2023-01-01], ~T[04:05:00], "America/New_York")

      sign_context =
        %{sign_context | current_time: now}
        |> update_in(
          [Access.key!(:config_contexts), Access.at(0)],
          &%{
            &1
            | first_scheduled_departure: DateTime.shift(now, hour: 1),
              last_scheduled_departure: DateTime.shift(now, hour: 10)
          }
        )

      assert [%Message.FirstTrain{destination: :southbound}] =
               Signs.Utilities.Messages.get_messages(
                 sign,
                 sign_context
               )
    end
  end
end
