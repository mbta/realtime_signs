defmodule Content.Audio.TrackChange do
  @moduledoc """
  The next train to [destination] is stopped [n] [stop/stops] away.
  """

  require Logger

  @enforce_keys [:destination, :track, :route_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          route_id: String.t(),
          track: integer()
        }

  @spec from_message(Content.Message.Predictions.t()) :: t() | nil
  def from_message(%Content.Message.Predictions{
        stop_id: "70197",
        route_id: route_id,
        minutes: :boarding,
        headsign: headsign
      })
      when route_id in ["Green-B", "Green-D"] do
    %__MODULE__{
      destination: headsign,
      route_id: route_id,
      track: 1
    }
  end

  def from_message(%Content.Message.Predictions{
        stop_id: "70199",
        route_id: route_id,
        minutes: :boarding,
        headsign: headsign
      })
      when route_id in ["Green-B", "Green-D"] do
    %__MODULE__{
      destination: headsign,
      route_id: route_id,
      track: 1
    }
  end

  def from_message(%Content.Message.Predictions{
        stop_id: "70196",
        route_id: route_id,
        minutes: :boarding,
        headsign: headsign
      })
      when route_id in ["Green-C", "Green-E"] do
    %__MODULE__{
      destination: headsign,
      route_id: route_id,
      track: 2
    }
  end

  def from_message(%Content.Message.Predictions{
        stop_id: "70198",
        route_id: route_id,
        minutes: :boarding,
        headsign: headsign
      })
      when route_id in ["Green-C", "Green-E"] do
    %__MODULE__{
      destination: headsign,
      route_id: route_id,
      track: 2
    }
  end

  def from_message(_message) do
    nil
  end

  defimpl Content.Audio do
    @track_change "540"
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"
    @on_track_1 "541"
    @on_track_2 "542"

    def to_params(audio) do
      vars = [
        @track_change,
        @the_next,
        branch_letter(audio.route_id),
        @train_to,
        PaEss.Utilities.destination_var(audio.destination),
        @is_now_boarding,
        track(audio.track)
      ]

      {"109", vars, :audio}
    end

    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2

    defp branch_letter("Green-B"), do: "536"
    defp branch_letter("Green-C"), do: "537"
    defp branch_letter("Green-D"), do: "538"
    defp branch_letter("Green-E"), do: "539"
  end
end
