defmodule GTFS.Realtime do
  use Protobuf, from: Path.expand("../../config/gtfs-realtime.proto", __DIR__)

  @type feed_message :: %__MODULE__.FeedMessage{
          header: feed_header,
          entity: [feed_entity]
        }

  @type feed_header :: %__MODULE__.FeedHeader{
          gtfs_realtime_version: String.t(),
          incrementality: nil | :FULL_DATASET | :DIFFERENTIAL,
          timestamp: nil | integer
        }

  @type feed_entity :: %__MODULE__.FeedEntity{
          id: String.t(),
          is_deleted: boolean,
          trip_update: nil | trip_update,
          vehicle: nil | vehicle_position,
          alert: nil | alert
        }

  @type trip_update :: %__MODULE__.TripUpdate{
          trip: trip_descriptor,
          vehicle: nil | vehicle_descriptor,
          stop_time_update: [trip_update_stop_time_update],
          timestamp: nil | integer,
          delay: nil | integer
        }

  @type trip_update_stop_time_event :: %__MODULE__.TripUpdate.StopTimeEvent{
          delay: nil | integer,
          time: nil | integer,
          uncertainty: nil | integer
        }

  @type trip_update_stop_time_update :: %__MODULE__.TripUpdate.StopTimeUpdate{
          stop_sequence: nil | integer,
          stop_id: nil | String.t(),
          arrival: nil | trip_update_stop_time_event,
          departure: nil | trip_update_stop_time_event,
          schedule_relationship: nil | :SCHEDULED | :SKIPPED | :NO_DATA
        }

  @type vehicle_position_statuses :: :INCOMING_AT | :STOPPED_AT | :IN_TRANSIT_TO

  @type vehicle_position :: %__MODULE__.VehiclePosition{
          trip: nil | trip_descriptor,
          vehicle: nil | vehicle_descriptor,
          position: nil | position,
          current_stop_sequence: nil | integer,
          stop_id: nil | String.t(),
          current_status: nil | vehicle_position_statuses,
          timestamp: nil | integer,
          congestion_level:
            nil
            | :UNKNOWN_CONGESTION_LEVEL
            | :RUNNING_SMOOTHLY
            | :STOP_AND_GO
            | :CONGESTION
            | :SEVERE_CONGESTION,
          occupancy_status:
            nil
            | :EMPTY
            | :MANY_SEATS_AVAILABLE
            | :FEW_SEATS_AVAILABLE
            | :STANDING_ROOM_ONLY
            | :CRUSHED_STANDING_ROOM_ONLY
            | :FULL
            | :NOT_ACCEPTING_PASSENGERS
        }

  @type alert :: %__MODULE__.Alert{
          active_period: [time_range],
          informed_entity: [entity_selector],
          cause:
            nil
            | :UNKNOWN_CAUSE
            | :OTHER_CAUSE
            | :TECHNICAL_PROBLEM
            | :STRIKE
            | :DEMONSTRATION
            | :ACCIDENT
            | :HOLIDAY
            | :WEATHER
            | :MAINTENANCE
            | :CONSTRUCTION
            | :POLICE_ACTIVITY
            | :MEDICAL_EMERGENCY,
          effect:
            nil
            | :NO_SERVICE
            | :REDUCED_SERVICE
            | :SIGNIFICANT_DELAYS
            | :DETOUR
            | :ADDITIONAL_SERVICE
            | :OTHER_EFFECT
            | :UNKNOWN_EFFECT
            | :STOP_MOVED,
          url: nil | translated_string,
          header_text: nil | translated_string,
          description_text: nil | translated_string
        }

  @type time_range :: %__MODULE__.TimeRange{
          start: nil | integer,
          end: nil | integer
        }

  @type position :: %__MODULE__.Position{
          latitude: float,
          longitude: float,
          bearing: nil | float,
          odometer: nil | float,
          speed: nil | float
        }

  @type trip_descriptor :: %__MODULE__.TripDescriptor{
          trip_id: nil | String.t(),
          route_id: nil | String.t(),
          direction_id: nil | integer,
          start_time: nil | String.t(),
          start_date: nil | String.t(),
          schedule_relationship: nil | :SCHEDULED | :ADDED | :UNSCHEDULED | :CANCELED
        }

  @type vehicle_descriptor :: %__MODULE__.VehicleDescriptor{
          id: nil | String.t(),
          label: nil | String.t(),
          license_plate: nil | String.t()
        }

  @type entity_selector :: %__MODULE__.EntitySelector{
          agency_id: nil | String.t(),
          route_id: nil | String.t(),
          route_type: nil | integer,
          trip: nil | trip_descriptor,
          stop_id: nil | String.t()
        }

  @type translated_string :: %__MODULE__.TranslatedString{
          translation: [translated_string_translation]
        }

  @type translated_string_translation :: %__MODULE__.TranslatedString.Translation{
          text: String.t(),
          language: nil | String.t()
        }
end
