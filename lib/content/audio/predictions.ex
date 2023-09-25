defmodule Content.Audio.Predictions do
  @moduledoc """
  Module to convert a Message.Predictions.t() struct into the
  appropriate audio struct, whether it's a NextTrainCountdown.t(),
  TrainIsArriving.t(), TrainIsBoarding.t(), or TrackChange.t().
  """

  require Logger
  require Content.Utilities
  alias Content.Audio

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
      predictions.minutes == :boarding ->
        Audio.TrainIsBoarding.from_message(predictions)

      predictions.minutes == :arriving ->
        Audio.TrainIsArriving.from_message(predictions, false)

      predictions.minutes == :approaching and (line == :top or multi_source?) and
          predictions.route_id in @heavy_rail_routes ->
        Audio.Approaching.from_message(predictions, false)

      true ->
        Audio.NextTrainCountdown.from_message(predictions)
    end
  end
end
