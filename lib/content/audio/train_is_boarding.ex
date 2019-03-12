defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger

  @enforce_keys [:destination, :route_id, :stop_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          route_id: String.t(),
          stop_id: String.t()
        }

  defimpl Content.Audio do
    @typep track_number :: non_neg_integer()

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

    def to_params(audio) do
      {vars, message_type} =
        case {branch_letter(audio.route_id), stop_track_number(audio.stop_id)} do
          {nil, nil} ->
            {[
               @the_next,
               @train_to,
               PaEss.Utilities.destination_var(audio.destination),
               @is_now_boarding
             ], :audio}

          {nil, track_number} ->
            {[
               @the_next,
               @train_to,
               PaEss.Utilities.destination_var(audio.destination),
               @is_now_boarding,
               track(track_number)
             ], :audio_visual}

          {branch_letter, _track_number} ->
            {[
               @the_next,
               branch_letter,
               @train_to,
               PaEss.Utilities.destination_var(audio.destination),
               @is_now_boarding
             ], :audio}
        end

      {PaEss.Utilities.take_message_id(vars), vars, message_type}
    end

    @spec track(track_number()) :: String.t()
    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2

    @spec stop_track_number(String.t()) :: track_number() | nil
    defp stop_track_number("Alewife-01"), do: 1
    defp stop_track_number("Alewife-02"), do: 2
    defp stop_track_number("Braintree-01"), do: 1
    defp stop_track_number("Braintree-02"), do: 2
    defp stop_track_number("Forest Hills-01"), do: 1
    defp stop_track_number("Forest Hills-02"), do: 2
    defp stop_track_number("Oak Grove-01"), do: 1
    defp stop_track_number("Oak Grove-02"), do: 2
    defp stop_track_number(_), do: nil

    @spec branch_letter(String.t()) :: String.t() | nil
    defp branch_letter("Green-B"), do: "536"
    defp branch_letter("Green-C"), do: "537"
    defp branch_letter("Green-D"), do: "538"
    defp branch_letter("Green-E"), do: "539"
    defp branch_letter(_), do: nil
  end
end
