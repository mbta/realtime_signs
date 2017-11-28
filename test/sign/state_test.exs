defmodule Sign.StateTest do
  use ExUnit.Case

  alias GTFS.Realtime.{FeedMessage, FeedEntity, TripUpdate, TripDescriptor, VehiclePosition}
  alias Sign.Canned, as: C
  alias Sign.Message, as: M
  alias Sign.Content, as: SC

  @fake_updater Fake.Sign.Updater
  @trip_id "32569007"

  # Use a fake sign updater that stores the calls we make
  setup_all do
    old_updater = Application.get_env(:realtime_signs, :sign_updater)
    Application.put_env(:realtime_signs, :sign_updater, @fake_updater)
    @fake_updater.start_link(name: @fake_updater)
    on_exit fn () ->
      Application.put_env(:realtime_signs, :sign_updater, old_updater)
    end
  end

  setup do
    on_exit fn () ->
      Sign.State.reset()
      @fake_updater.reset()
    end
  end

  defp trip_update_entity(arrival_time, stop_id, direction_id) do
    %FeedEntity{
      trip_update: %TripUpdate {
        trip: %TripDescriptor{
          direction_id: direction_id,
          trip_id: @trip_id},
        stop_time_update: [
          %TripUpdate.StopTimeUpdate{
            arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{time: Timex.to_unix(arrival_time)},
            stop_id: stop_id}
        ]}}
  end

  test "sends messages when a train is coming towards a configured station" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, minutes: 3), "70268", 0)
      ]
    }

    Sign.State.update(trip_updates, %FeedMessage{entity: []}, now)

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 180,
            message: [{"Mattapan     3 min", nil}],
            placement: ["s1"],
            when: nil},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"},

    ]
  end

  test "doesn't send messages to a station that is turned off" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, minutes: 3), "11111", 0)
      ]
    }

    Sign.State.update(trip_updates, %FeedMessage{entity: []}, now)

    assert @fake_updater.all_calls == []
  end

  test "sends ARR and a canned message when the train is less than a minute away" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, seconds: 25), "70268", 0)
      ]
    }

    Sign.State.update(trip_updates, %FeedMessage{entity: []}, now)

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 30,
            message: [{"Mattapan       ARR", nil}],
            placement: ["s1"],
            when: nil},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"},
      %C{
        mid: 90128,
        platforms: %Sign.Platforms{sb: true},
        priority: 5,
        station: "MMIL",
        timeout: 60,
        type: 1,
        variables: []}
    ]
  end

  test "doesn't send an ARR message twice for the same trip" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates_1 = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, seconds: 25), "70268", 0)
      ]
    }

    Sign.State.update(trip_updates_1, %FeedMessage{entity: []}, now)

    trip_updates_2 = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, seconds: 15), "70268", 0)
      ]
    }

    Sign.State.update(trip_updates_2, %FeedMessage{entity: []}, now)

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 30,
            message: [{"Mattapan       ARR", nil}],
            placement: ["s1"],
            when: nil},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"},
      %C{
        mid: 90128,
        platforms: %Sign.Platforms{sb: true},
        priority: 5,
        station: "MMIL",
        timeout: 60,
        type: 1,
        variables: []}
    ]
  end

  test "doesn't send a new message if the content will be the same" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, minutes: 3), "70268", 0)
      ]
    }

    Sign.State.update(trip_updates, %FeedMessage{entity: []}, now)

    # Send the same update, a bit later
    Sign.State.update(trip_updates, %FeedMessage{entity: []}, Timex.shift(now, seconds: 10))

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 180,
            message: [{"Mattapan     3 min", nil}],
            placement: ["s1"],
            when: nil},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"}
    ]
  end

  test "does send a new message if the content will be the same but three minutes have passed" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates_1 = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, minutes: 3), "70268", 0)
      ]
    }

    Sign.State.update(trip_updates_1, %FeedMessage{entity: []}, now)

    # Send the same update four minutes later -- the train is still
    # coming in three minutes from "now"
    trip_updates_2 = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, minutes: 7), "70268", 0)
      ]
    }
    Sign.State.update(trip_updates_2, %FeedMessage{entity: []}, Timex.shift(now, minutes: 4))

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 180,
            message: [{"Mattapan     3 min", nil}],
            placement: ["s1"],
            when: nil},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"},
      %SC{
        messages: [
          %M{
            duration: 180,
            message: [{"Mattapan     3 min", nil}],
            placement: ["s1"],
            when: nil},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"}
    ]
  end

  test "sends a BRD message if a vehicle is at the station" do
    now = ~N[2017-06-05 12:00:00]
    stop_id = "70268"
    vehicle_positions = %FeedMessage{
      entity: [
        %FeedEntity{
          vehicle: %VehiclePosition{
            stop_id: stop_id,
            current_status: :STOPPED_AT,
            trip: %TripDescriptor{direction_id: 0, trip_id: @trip_id},
          }
        }
      ]
    }

    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, seconds: 5), stop_id, 0)
      ]
    }

    Sign.State.update(trip_updates, vehicle_positions, now)

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 10,
            message: [{"Mattapan       BRD", nil}],
            placement: ["s1"]},
          %M{
            duration: nil,
            message: [{"                  ", nil}],
            placement: ["s2"],
            when: nil}
        ],
        station: "MMIL"}
    ]
  end

  test "for stations configured as one_line, sends messages only for the first trip" do
    now = ~N[2017-06-05 12:00:00]
    stop_id = "70262"
    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, minutes: 5), stop_id, 0),
        trip_update_entity(Timex.shift(now, minutes: 3), stop_id, 0)
      ]
    }

    Sign.State.update(trip_updates, %FeedMessage{entity: []}, now)

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 180,
            message: [{"Mattapan  3 min", nil}], placement: ["m1"], when: nil}
        ],
        station: "RASH"}
    ]
  end

  test "when a train is incoming to Ashmont, announces it as next going to Mattapan" do
    now = ~N[2017-06-05 12:00:00]
    trip_updates = %FeedMessage{
      entity: [
        trip_update_entity(Timex.shift(now, seconds: 25), "70262", 1)
      ]
    }

    Sign.State.update(trip_updates, %FeedMessage{entity: []}, now)

    assert @fake_updater.all_calls == [
      %SC{
        messages: [
          %M{
            duration: 30,
            message: [{"Mattapan    ARR", nil}],
            placement: ["m1"],
            when: nil}
        ],
        station: "RASH"},
      %C{
        mid: 90128,
        platforms: %Sign.Platforms{mz: true},
        priority: 5,
        station: "RASH",
        timeout: 60,
        type: 1,
        variables: []}
    ]
  end
end
