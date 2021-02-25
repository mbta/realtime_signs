defmodule Content.Audio.TrackChange do
  @moduledoc """
  Track change: The next [line] train to [destination] is now boarding on [track]
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

    def to_params(audio) do
      case PaEss.Utilities.destination_var(audio.destination) do
        {:ok, dest_var} ->
          vars =
            case Content.Utilities.route_and_destination_branch_letter(
                   audio.route_id,
                   audio.destination
                 ) do
              nil ->
                [
                  @track_change,
                  @the_next,
                  @train_to,
                  dest_var,
                  @is_now_boarding,
                  track(audio.track)
                ]

              branch ->
                [
                  @track_change,
                  @the_next,
                  PaEss.Utilities.green_line_branch_var(branch),
                  @train_to,
                  dest_var,
                  @is_now_boarding,
                  track(audio.track)
                ]
            end

          PaEss.Utilities.take_message(vars, :audio_visual)

        {:error, :unknown} ->
          Logger.error("TrackChange.to_params unknown destination: #{inspect(audio.destination)}")
          nil
      end
    end

    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2
  end
end
