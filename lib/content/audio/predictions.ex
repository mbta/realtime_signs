defmodule Content.Audio.Predictions do
  @moduledoc """
  Module to convert a Message.Predictions.t() struct into the
  appropriate audio struct, whether it's a NextTrainCountdown.t(),
  TrainIsArriving.t(), TrainIsBoarding.t(), or TrackChange.t().
  """

  require Logger
  require Content.Utilities
  alias Content.Audio.TrackChange
  alias Content.Audio.TrainIsBoarding
  alias Content.Audio.TrainIsArriving
  alias Content.Audio.Approaching
  alias Content.Audio.NextTrainCountdown

  @heavy_rail_routes ["Red", "Orange", "Blue"]

  @spec from_sign_content(
          Content.Message.Predictions.t(),
          Content.line_location(),
          boolean()
        ) :: [Content.Audio.t()]
  def from_sign_content(
        %Content.Message.Predictions{} = predictions,
        line,
        multi_source?
      ) do
    cond do
      TrackChange.park_track_change?(predictions) and predictions.minutes == :boarding ->
        [
          %TrackChange{
            destination: predictions.destination,
            route_id: predictions.route_id,
            berth: predictions.stop_id
          }
        ]

      predictions.minutes == :boarding ->
        [
          %TrainIsBoarding{
            destination: predictions.destination,
            trip_id: predictions.trip_id,
            route_id: predictions.route_id,
            track_number: Content.Utilities.stop_track_number(predictions.stop_id)
          }
        ]

      predictions.minutes == :arriving ->
        if predictions.crowding_data_confidence == :high do
          # TODO: Pass along crowding data classification once available
          [
            %TrainIsArriving{
              destination: predictions.destination,
              trip_id: predictions.trip_id,
              platform: predictions.platform,
              route_id: predictions.route_id
            }
          ]
        else
          [
            %TrainIsArriving{
              destination: predictions.destination,
              trip_id: predictions.trip_id,
              platform: predictions.platform,
              route_id: predictions.route_id
            }
          ]
        end

      predictions.minutes == :approaching and (line == :top or multi_source?) and
          predictions.route_id in @heavy_rail_routes ->
        if predictions.crowding_data_confidence == :high do
          # TODO: Pass along crowding data classification once available
          [
            %Approaching{
              destination: predictions.destination,
              trip_id: predictions.trip_id,
              platform: predictions.platform,
              route_id: predictions.route_id,
              new_cars?: predictions.new_cars?
            }
          ]
        else
          [
            %Approaching{
              destination: predictions.destination,
              trip_id: predictions.trip_id,
              platform: predictions.platform,
              route_id: predictions.route_id,
              new_cars?: predictions.new_cars?
            }
          ]
        end

      predictions.minutes == :approaching ->
        [
          %NextTrainCountdown{
            destination: predictions.destination,
            route_id: predictions.route_id,
            minutes: 1,
            verb: if(predictions.terminal?, do: :departs, else: :arrives),
            track_number: Content.Utilities.stop_track_number(predictions.stop_id),
            platform: predictions.platform,
            station_code: predictions.station_code,
            zone: predictions.zone
          }
        ]

      predictions.minutes == :max_time ->
        [
          %NextTrainCountdown{
            destination: predictions.destination,
            route_id: predictions.route_id,
            minutes: div(Content.Utilities.max_time_seconds(), 60),
            verb: if(predictions.terminal?, do: :departs, else: :arrives),
            track_number: Content.Utilities.stop_track_number(predictions.stop_id),
            platform: predictions.platform,
            station_code: predictions.station_code,
            zone: predictions.zone
          }
        ]

      is_integer(predictions.minutes) ->
        [
          %NextTrainCountdown{
            destination: predictions.destination,
            route_id: predictions.route_id,
            minutes: predictions.minutes,
            verb: if(predictions.terminal?, do: :departs, else: :arrives),
            track_number: Content.Utilities.stop_track_number(predictions.stop_id),
            platform: predictions.platform,
            station_code: predictions.station_code,
            zone: predictions.zone
          }
        ]

      true ->
        []
    end
  end
end
