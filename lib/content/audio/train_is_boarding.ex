defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger
  alias Content.Audio
  alias Content.Message

  @enforce_keys [:destination, :route_id, :track_number]
  defstruct @enforce_keys ++ [:trip_id]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          route_id: String.t(),
          track_number: Content.Utilities.track_number()
        }

  def from_message(%Message.Predictions{} = message) do
    if Audio.TrackChange.park_track_change?(message) do
      [
        %Audio.TrackChange{
          destination: message.destination,
          route_id: message.prediction.route_id,
          berth: message.prediction.stop_id
        }
      ]
    else
      [
        %__MODULE__{
          destination: message.destination,
          trip_id: message.prediction.trip_id,
          route_id: message.prediction.route_id,
          track_number: Content.Utilities.stop_track_number(message.prediction.stop_id)
        }
      ] ++
        if message.special_sign == :bowdoin_eastbound do
          [%Audio.BoardingButton{}]
        else
          []
        end
    end
  end

  defimpl Content.Audio do
    @the_next "501"
    @train_to "507"
    @is_now_boarding "544"
    @on_track_1 "541"
    @on_track_2 "542"

    def to_params(audio) do
      if PaEss.Utilities.directional_destination?(audio.destination) do
        do_ad_hoc_message(audio)
      else
        do_to_params(audio, PaEss.Utilities.destination_var(audio.destination))
      end
    end

    def to_tts(%Content.Audio.TrainIsBoarding{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.TrainIsBoarding{}) do
      []
    end

    defp tts_text(%Content.Audio.TrainIsBoarding{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)
      track = if(audio.track_number, do: " on track #{audio.track_number}", else: ".")
      "The next #{train} is now boarding#{track}"
    end

    defp do_ad_hoc_message(audio) do
      {:ad_hoc, {tts_text(audio), :audio}}
    end

    defp do_to_params(%{destination: destination, route_id: "Green-" <> _branch}, destination_var)
         when destination in [
                :lechmere,
                :north_station,
                :government_center,
                :park_st,
                :kenmore,
                :union_square,
                :medford_tufts
              ] do
      vars = [
        @the_next,
        @train_to,
        destination_var,
        @is_now_boarding
      ]

      PaEss.Utilities.take_message(vars, :audio)
    end

    defp do_to_params(
           %{route_id: route_id, track_number: track_number},
           destination_var
         ) do
      vars =
        case {Content.Utilities.route_branch_letter(route_id), track_number} do
          {nil, nil} ->
            [
              @the_next,
              @train_to,
              destination_var,
              @is_now_boarding
            ]

          {nil, track_number} ->
            [
              @the_next,
              @train_to,
              destination_var,
              @is_now_boarding,
              track(track_number)
            ]

          {green_line_branch, _track_number} ->
            [
              @the_next,
              PaEss.Utilities.green_line_branch_var(green_line_branch),
              @train_to,
              destination_var,
              @is_now_boarding
            ]
        end

      PaEss.Utilities.take_message(vars, :audio)
    end

    @spec track(Content.Utilities.track_number()) :: String.t()
    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2
  end
end
