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

  @spec from_message(Content.Message.Predictions.t()) :: t() | nil
  def from_message(%Content.Message.Predictions{
        stop_id: stop_id,
        route_id: route_id,
        minutes: :boarding,
        headsign: headsign
      }) do
    {:ok, dest} = PaEss.Utilities.headsign_to_terminal_station(headsign)

    %__MODULE__{
      destination: dest,
      route_id: route_id
    }
  end

  def from_message(_message) do
    nil
  end

  defimpl Content.Audio do
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"

    def to_params(audio) do
      vars = [
        @the_next,
        branch_letter(audio.route_id),
        @train_to,
        PaEss.Utilities.destination_var(audio.destination),
        @is_now_boarding
      ]

      {"109", vars, :audio}
    end

    defp branch_letter("Green-B"), do: "536"
    defp branch_letter("Green-C"), do: "537"
    defp branch_letter("Green-D"), do: "538"
    defp branch_letter("Green-E"), do: "539"
  end
end
