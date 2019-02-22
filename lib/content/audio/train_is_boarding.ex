defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger

  @enforce_keys [:destination, :route_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          route_id: String.t()
        }

  defimpl Content.Audio do
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"

    def to_params(%{destination: destination})
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
      vars = [
        @the_next,
        branch_letter(audio.route_id),
        @train_to,
        PaEss.Utilities.destination_var(audio.destination),
        @is_now_boarding
      ]

      {PaEss.Utilities.take_message_id(vars), vars, :audio}
    end

    @spec branch_letter(String.t()) :: String.t()
    defp branch_letter("Green-B"), do: "536"
    defp branch_letter("Green-C"), do: "537"
    defp branch_letter("Green-D"), do: "538"
    defp branch_letter("Green-E"), do: "539"
    defp branch_letter(_), do: nil
  end
end
