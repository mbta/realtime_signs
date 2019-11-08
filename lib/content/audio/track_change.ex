defmodule Content.Audio.TrackChange do
  @moduledoc """
  Track change: The next [line] train to [desitnation] is now boarding on [track]
  """

  require Logger

  @enforce_keys [:destination, :track, :route_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          track: integer()
        }

  defimpl Content.Audio do
    @track_change "540"
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"
    @on_track_1 "541"
    @on_track_2 "542"
    @space "21000"

    def to_params(audio) do
      case PaEss.Utilities.destination_var(audio.destination) do
        {:ok, dest_var} ->
          vars = [
            @track_change,
            @space,
            @the_next,
            @space,
            branch_letter(audio.route_id),
            @space,
            @train_to,
            @space,
            dest_var,
            @space,
            @is_now_boarding,
            @space,
            track(audio.track)
          ]

          {:canned, {"109", vars, :audio_visual}}

        {:error, :unknown} ->
          Logger.error("TrackChange.to_params unknown destination: #{inspect(audio.destination)}")
          nil
      end
    end

    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2

    defp branch_letter("Green-B"), do: "536"
    defp branch_letter("Green-C"), do: "537"
    defp branch_letter("Green-D"), do: "538"
    defp branch_letter("Green-E"), do: "539"
  end
end
