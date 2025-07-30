defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  @spec get_passthrough_train_audio(Signs.Realtime.predictions(), Signs.Realtime.t()) ::
          [Content.Audio.t()]
  def get_passthrough_train_audio(predictions, sign) do
    case {sign.source_config, predictions} do
      {{top_config, bottom_config}, {top_predictions, bottom_predictions}} ->
        [{top_config, top_predictions}, {bottom_config, bottom_predictions}]

      {config, predictions} ->
        [{config, predictions}]
    end
    |> Enum.flat_map(fn {config, predictions} ->
      Enum.filter(predictions, fn prediction ->
        prediction.seconds_until_passthrough &&
          prediction.seconds_until_passthrough <=
            secs_to_announce_passthrough(prediction.route_id)
      end)
      |> Enum.sort_by(fn prediction -> prediction.seconds_until_passthrough end)
      |> Enum.flat_map(fn prediction ->
        [
          %Content.Audio.Passthrough{
            destination: config.headway_destination,
            trip_id: prediction.trip_id,
            route_id: prediction.route_id
          }
        ]
      end)
      |> Enum.take(1)
    end)
  end

  @spec secs_to_announce_passthrough(String.t()) :: integer()
  defp secs_to_announce_passthrough("Green-" <> _), do: 30
  defp secs_to_announce_passthrough(_other), do: 60
end
