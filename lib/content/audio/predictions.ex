defmodule Content.Audio.Predictions do
  @moduledoc """
  Module to convert a Message.Predictions.t() struct into the
  appropriate audio struct, whether it's a NextTrainCountdown.t(),
  TrainIsArriving.t(), TrainIsBoarding.t(), or TrackChange.t().
  """

  require Logger
  alias Content.Audio.TrackChange
  alias Content.Audio.TrainIsBoarding
  alias Content.Audio.TrainIsArriving
  alias Content.Audio.Approaching
  alias Content.Audio.NextTrainCountdown

  @spec from_sign_content(
          {Signs.Utilities.SourceConfig.source(), Content.Message.Predictions.t()},
          Content.line(),
          boolean()
        ) :: nil | Content.Audio.t()
  def from_sign_content(
        {%Signs.Utilities.SourceConfig{} = src, %Content.Message.Predictions{} = predictions},
        line,
        multi_source?
      ) do
    case PaEss.Utilities.headsign_to_terminal_station(predictions.headsign) do
      {:ok, headsign} ->
        cond do
          predictions.route_id in ["Green-B", "Green-D"] and
            predictions.stop_id in ["70197", "70199"] and predictions.minutes == :boarding ->
            %TrackChange{destination: headsign, route_id: predictions.route_id, track: 1}

          predictions.route_id in ["Green-C", "Green-E"] and
            predictions.stop_id in ["70196", "70198"] and predictions.minutes == :boarding ->
            %TrackChange{destination: headsign, route_id: predictions.route_id, track: 2}

          predictions.minutes == :boarding ->
            %TrainIsBoarding{
              destination: headsign,
              route_id: predictions.route_id,
              track_number: Content.Utilities.stop_track_number(predictions.stop_id)
            }

          predictions.minutes == :arriving ->
            %TrainIsArriving{
              destination: headsign,
              trip_id: predictions.trip_id,
              platform: src.platform,
              route_id: predictions.route_id
            }

          predictions.minutes == :approaching and (line == :top or multi_source?) ->
            %Approaching{
              destination: headsign,
              trip_id: predictions.trip_id,
              platform: src.platform,
              route_id: predictions.route_id
            }

          predictions.minutes == :approaching and line == :bottom ->
            %NextTrainCountdown{
              destination: headsign,
              minutes: 1,
              verb: if(src.terminal?, do: :departs, else: :arrives),
              track_number: Content.Utilities.stop_track_number(predictions.stop_id),
              platform: src.platform
            }

          predictions.minutes == :thirty_plus ->
            %NextTrainCountdown{
              destination: headsign,
              minutes: 30,
              verb: if(src.terminal?, do: :departs, else: :arrives),
              track_number: Content.Utilities.stop_track_number(predictions.stop_id),
              platform: src.platform
            }

          is_integer(predictions.minutes) ->
            %NextTrainCountdown{
              destination: headsign,
              minutes: predictions.minutes,
              verb: if(src.terminal?, do: :departs, else: :arrives),
              track_number: Content.Utilities.stop_track_number(predictions.stop_id),
              platform: src.platform
            }
        end

      {:error, :unknown} ->
        Logger.warn("Content.Audio.Predictions unknown headsign #{predictions.headsign}")
        nil
    end
  end
end
