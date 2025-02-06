defmodule Content.Audio.TrackChange do
  @moduledoc """
  Track change: The next [line] train to [destination] is now boarding on [track]
  """

  require Logger

  @enforce_keys [:destination, :berth, :route_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          berth: String.t()
        }

  @spec park_track_change?(Predictions.Prediction.t()) :: boolean()
  def park_track_change?(%{route_id: "Green-B", stop_id: "70197"}), do: true
  def park_track_change?(%{route_id: "Green-C", stop_id: "70196"}), do: true
  def park_track_change?(%{route_id: "Green-D", stop_id: "70199"}), do: true
  def park_track_change?(%{route_id: "Green-E", stop_id: "70198"}), do: true
  def park_track_change?(_prediction), do: false

  defimpl Content.Audio do
    @track_change "540"
    @b_to_boston_college_c_platform "813"
    @c_to_cleveland_circle_b_platform "814"
    @d_to_reservoir_e_platform "815"
    @d_to_riverside_e_platform "818"
    @e_to_heath_d_platform "816"
    @kenmore_b_platform "823"
    @kenmore_c_platform "820"
    @kenmore_d_platform "821"
    @kenmore_e_platform "822"

    def to_params(audio) do
      case {audio.route_id, audio.berth, audio.destination} do
        {"Green-B", "70197", :boston_college} ->
          track_change_message(@b_to_boston_college_c_platform)

        {"Green-B", "70197", :kenmore} ->
          track_change_message(@kenmore_c_platform)

        {"Green-C", "70196", :cleveland_circle} ->
          track_change_message(@c_to_cleveland_circle_b_platform)

        {"Green-C", "70196", :kenmore} ->
          track_change_message(@kenmore_b_platform)

        {"Green-D", "70199", :reservoir} ->
          track_change_message(@d_to_reservoir_e_platform)

        {"Green-D", "70199", :riverside} ->
          track_change_message(@d_to_riverside_e_platform)

        {"Green-D", "70199", :kenmore} ->
          track_change_message(@kenmore_e_platform)

        {"Green-E", "70198", :heath_street} ->
          track_change_message(@e_to_heath_d_platform)

        {"Green-E", "70198", :kenmore} ->
          track_change_message(@kenmore_d_platform)

        {route, berth, destination} ->
          Logger.error(
            "TrackChange.to_params unknown route, berth, destination: #{inspect({route, berth, destination})}"
          )

          nil
      end
    end

    def to_tts(%Content.Audio.TrackChange{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)

      platform =
        case audio.berth do
          "70196" -> "B"
          "70197" -> "C"
          "70198" -> "D"
          "70199" -> "E"
        end

      text = "Track change: The next #{train} is now boarding on the #{platform} platform"
      {text, PaEss.Utilities.paginate_text(text)}
    end

    def to_logs(%Content.Audio.TrackChange{}) do
      []
    end

    defp track_change_message(msg_id) do
      vars = [@track_change, msg_id]
      PaEss.Utilities.take_message(vars, :audio_visual)
    end
  end
end
