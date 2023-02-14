defmodule Content.Audio.TrainIsBoarding do
  @moduledoc """
  The next train to [destination] is now boarding.
  """

  require Logger

  @enforce_keys [:destination, :route_id, :track_number]
  defstruct @enforce_keys ++ [:trip_id]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
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

    def to_params(audio) do
      case PaEss.Utilities.destination_var(audio.destination) do
        {:ok, destination_var} ->
          do_to_params(audio, destination_var)

        {:error, :unknown} ->
          case PaEss.Utilities.ad_hoc_trip_description(audio.destination) do
            {:ok, trip_description} ->
              text =
                if audio.track_number do
                  "The next #{trip_description} is now boarding, on track #{audio.track_number}"
                else
                  "The next #{trip_description} is now boarding"
                end

              {:ad_hoc, {text, :audio}}

            {:error, :unknown} ->
              Logger.error("TrainIsBoarding.to_params unknown destination: #{audio.destination}")
              nil
          end
      end
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
