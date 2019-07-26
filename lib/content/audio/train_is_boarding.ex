defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger

  @enforce_keys [:destination, :route_id, :track_number]
  defstruct @enforce_keys ++ [:trip_id]

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          route_id: String.t(),
          track_number: Content.Utilities.track_number()
        }

  defimpl Content.Audio do
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"
    @on_track_1 "541"
    @on_track_2 "542"
    @space "21000"

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

    def to_params(%{destination: destination, route_id: route_id, track_number: track_number}) do
      {vars, message_type} =
        case {branch_letter(route_id), track_number} do
          {nil, nil} ->
            {[
               @the_next,
               @train_to,
               PaEss.Utilities.destination_var(destination),
               @is_now_boarding
             ], :audio}

          {nil, track_number} ->
            {[
               @the_next,
               @space,
               @train_to,
               @space,
               PaEss.Utilities.destination_var(destination),
               @space,
               @is_now_boarding,
               @space,
               track(track_number)
             ], :audio}

          {branch_letter, _track_number} ->
            {[
               @the_next,
               branch_letter,
               @train_to,
               PaEss.Utilities.destination_var(destination),
               @is_now_boarding
             ], :audio}
        end

      {PaEss.Utilities.take_message_id(vars), vars, message_type}
    end

    @spec track(Content.Utilities.track_number()) :: String.t()
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
