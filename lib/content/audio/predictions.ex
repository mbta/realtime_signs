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
  alias Content.Audio.NextTrainCountdown

  @spec from_sign_content(
          {Signs.Utilities.SourceConfig.source(), Content.Message.Predictions.t()}
        ) :: nil | Content.Audio.t()
  def from_sign_content(
        {%Signs.Utilities.SourceConfig{} = src, %Content.Message.Predictions{} = predictions}
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
            %TrainIsBoarding{destination: headsign, route_id: predictions.route_id}

          predictions.minutes == :arriving ->
            %TrainIsArriving{destination: headsign}

          predictions.minutes == :thirty_plus ->
            %NextTrainCountdown{
              destination: headsign,
              minutes: 30,
              verb: if(src.terminal?, do: :departs, else: :arrives),
              platform: src.platform
            }

          is_integer(predictions.minutes) ->
            %NextTrainCountdown{
              destination: headsign,
              minutes: predictions.minutes,
              verb: if(src.terminal?, do: :departs, else: :arrives),
              platform: src.platform
            }
        end

      {:error, :unknown} ->
        Logger.warn("Content.Audio.Predictions unknown headsign #{predictions.headsign}")
        nil
    end
  end
end