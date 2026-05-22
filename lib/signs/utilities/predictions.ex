defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  alias Signs.Utilities.SignContext

  @spec get_passthrough_train_audio(SignContext.t()) :: [Content.Audio.t()]
  def get_passthrough_train_audio(%SignContext{} = sign_context) do
    Enum.flat_map(sign_context.config_contexts, fn config_context ->
      Enum.filter(config_context.predictions, fn prediction ->
        prediction.schedule_relationship == :skipped &&
          prediction.seconds_until_arrival &&
          prediction.seconds_until_arrival <=
            secs_to_announce_passthrough(prediction.route_id)
      end)
      |> Enum.sort_by(fn prediction -> prediction.seconds_until_arrival end)
      |> Enum.flat_map(fn prediction ->
        [
          %Content.Audio.Passthrough{
            destination: config_context.config.headway_destination,
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
