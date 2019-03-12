defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger

  @enforce_keys [:destination, :route_id, :track]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          route_id: String.t(),
          track: Content.Message.Predictions.track_number() | nil
        }

  defimpl Content.Audio do
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"
    @on_track_1 "541"
    @on_track_2 "542"

    def to_params(%{destination: destination, route_id: "Green-" <> _branch})
        when destination in [:lechmere, :north_station, :government_center, :park_st, :kenmore] do
      vars = [
        @the_next,
        @train_to,
        PaEss.Utilities.destination_var(destination),
        @is_now_boarding
      ]

      {PaEss.Utilities.take_message_id(vars), vars, :audio}
    end

    def to_params(%{track: track} = audio) when not is_nil(track) do
      vars = [
        @the_next,
        @train_to,
        PaEss.Utilities.destination_var(audio.destination),
        @is_now_boarding,
        track(track)
      ]

      {PaEss.Utilities.take_message_id(vars), vars, :audio}
    end

    def to_params(audio) do
      vars =
        case branch_letter(audio.route_id) do
          nil ->
            [
              @the_next,
              @train_to,
              PaEss.Utilities.destination_var(audio.destination),
              @is_now_boarding
            ]

          branch_letter ->
            [
              @the_next,
              branch_letter,
              @train_to,
              PaEss.Utilities.destination_var(audio.destination),
              @is_now_boarding
            ]
        end

      {PaEss.Utilities.take_message_id(vars), vars, :audio}
    end

    @spec track(Content.Message.Predictions.track_number()) :: String.t()
    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2

    @spec branch_letter(String.t()) :: String.t() | nil
    defp branch_letter("Green-B"), do: "536"
    defp branch_letter("Green-C"), do: "537"
    defp branch_letter("Green-D"), do: "538"
    defp branch_letter("Green-E"), do: "539"
    defp branch_letter(_), do: nil
  end
end
