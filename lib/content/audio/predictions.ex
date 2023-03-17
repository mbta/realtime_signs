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
          {Signs.Utilities.SourceConfig.source(), Content.Message.Predictions.t()},
          Content.line_location(),
          boolean()
        ) :: nil | Content.Audio.t()
  def from_sign_content(
        {%Signs.Utilities.SourceConfig{} = src, %Content.Message.Predictions{} = predictions},
        line,
        multi_source?
      ) do
    cond do
      TrackChange.park_track_change?(predictions) and predictions.minutes == :boarding ->
        %TrackChange{
          destination: predictions.destination,
          route_id: predictions.route_id,
          berth: predictions.stop_id
        }

      predictions.minutes == :boarding ->
        %TrainIsBoarding{
          destination: predictions.destination,
          trip_id: predictions.trip_id,
          route_id: predictions.route_id,
          track_number: Content.Utilities.stop_track_number(predictions.stop_id)
        }

      predictions.minutes == :arriving ->
        %TrainIsArriving{
          destination: predictions.destination,
          trip_id: predictions.trip_id,
          platform: src.platform,
          route_id: predictions.route_id
        }

      predictions.minutes == :approaching and (line == :top or line == :neither or multi_source?) and
          predictions.route_id in @heavy_rail_routes ->
        %Approaching{
          destination: predictions.destination,
          trip_id: predictions.trip_id,
          platform: src.platform,
          route_id: predictions.route_id,
          new_cars?: predictions.new_cars?
        }

      predictions.minutes == :approaching ->
        %NextTrainCountdown{
          destination: predictions.destination,
          route_id: predictions.route_id,
          minutes: 1,
          verb: if(src.terminal?, do: :departs, else: :arrives),
          track_number: Content.Utilities.stop_track_number(predictions.stop_id),
          platform: src.platform,
          station_code: predictions.station_code,
          zone: predictions.zone
        }

      predictions.minutes == :max_time ->
        %NextTrainCountdown{
          destination: predictions.destination,
          route_id: predictions.route_id,
          minutes: div(Content.Utilities.max_time_seconds(), 60),
          verb: if(src.terminal?, do: :departs, else: :arrives),
          track_number: Content.Utilities.stop_track_number(predictions.stop_id),
          platform: src.platform,
          station_code: predictions.station_code,
          zone: predictions.zone
        }

      is_integer(predictions.minutes) ->
        %NextTrainCountdown{
          destination: predictions.destination,
          route_id: predictions.route_id,
          minutes: predictions.minutes,
          verb: if(src.terminal?, do: :departs, else: :arrives),
          track_number: Content.Utilities.stop_track_number(predictions.stop_id),
          platform: src.platform,
          station_code: predictions.station_code,
          zone: predictions.zone
        }
    end
  end
end
