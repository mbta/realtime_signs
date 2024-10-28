defmodule Content.Message.Predictions do
  @moduledoc """
  A message related to real time predictions. For example:

  Mattapan    BRD
  Mattapan    ARR
  Mattapan  2 min

  The constructor should be used rather than creating a struct
  yourself.
  """

  require Logger
  require Content.Utilities

  @terminal_brd_seconds 30
  @terminal_prediction_offset_seconds -60
  @reverse_prediction_certainty 360

  @enforce_keys [:destination, :minutes]
  defstruct [
    :destination,
    :minutes,
    :approximate?,
    :prediction,
    :station_code,
    :zone,
    new_cars?: false,
    terminal?: false,
    crowding_data_confidence: nil,
    crowding_description: nil
  ]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          minutes: integer() | :boarding | :arriving | :approaching,
          approximate?: boolean(),
          prediction: Predictions.Prediction.t(),
          new_cars?: boolean(),
          station_code: String.t() | nil,
          zone: String.t() | nil,
          terminal?: boolean(),
          crowding_data_confidence: :high | :low | nil,
          crowding_description: {atom(), atom()} | nil
        }

  @spec non_terminal(Predictions.Prediction.t(), String.t(), String.t(), Signs.Realtime.t()) ::
          t() | nil
  def non_terminal(prediction, station_code, zone, sign) do
    # e.g., North Station which is non-terminal but has trips that begin there
    predicted_time = prediction.seconds_until_arrival || prediction.seconds_until_departure

    certainty =
      if prediction.seconds_until_arrival,
        do: prediction.arrival_certainty,
        else: prediction.departure_certainty

    {minutes, approximate?} =
      cond do
        prediction.stops_away == 0 -> {:boarding, false}
        predicted_time <= 30 -> {:arriving, false}
        predicted_time <= 60 -> {:approaching, false}
        true -> compute_minutes(predicted_time, certainty)
      end

    {crowding_data_confidence, crowding_description} =
      if Signs.Utilities.SourceConfig.multi_source?(sign.source_config),
        do: {nil, nil},
        else: do_crowding(prediction, sign)

    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      minutes: minutes,
      approximate?: approximate?,
      prediction: prediction,
      new_cars?: sign.location_engine.for_vehicle(prediction.vehicle_id) |> new_cars?(),
      station_code: station_code,
      zone: zone,
      crowding_data_confidence: crowding_data_confidence,
      crowding_description: crowding_description
    }
  end

  @spec terminal(Predictions.Prediction.t(), String.t(), String.t(), Signs.Realtime.t()) ::
          t() | nil
  def terminal(prediction, station_code, zone, sign) do
    stopped_at? = prediction.stops_away == 0

    {minutes, approximate?} =
      case prediction.seconds_until_departure + @terminal_prediction_offset_seconds do
        x when x <= @terminal_brd_seconds and stopped_at? -> {:boarding, false}
        x when x <= @terminal_brd_seconds -> {1, false}
        x -> compute_minutes(x, prediction.departure_certainty)
      end

    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      minutes: minutes,
      approximate?: approximate?,
      prediction: prediction,
      new_cars?: sign.location_engine.for_vehicle(prediction.vehicle_id) |> new_cars?(),
      station_code: station_code,
      zone: zone,
      terminal?: true
    }
  end

  defp compute_minutes(sec, certainty) do
    min = round(sec / 60)

    cond do
      min > 60 -> {60, true}
      certainty == @reverse_prediction_certainty && min > 20 -> {div(min, 10) * 10, true}
      true -> {min, false}
    end
  end

  defp do_crowding(prediction, sign) when prediction.route_id in ["Orange"] do
    case sign.location_engine.for_vehicle(prediction.vehicle_id) do
      %Locations.Location{} = location ->
        {calculate_crowding_data_confidence(prediction, location),
         get_crowding_description(location.multi_carriage_details)}

      _ ->
        {nil, nil}
    end
  end

  defp do_crowding(_, _), do: {nil, nil}

  defp calculate_crowding_data_confidence(prediction, location)
       when location.stop_id == prediction.stop_id do
    if location.status in [:incoming_at, :in_transit_to],
      do: :high,
      else: :low
  end

  defp calculate_crowding_data_confidence(_prediction, _location), do: nil

  defp get_crowding_description([_, _, _, _, _, _] = carriage_details) do
    crowding_levels =
      Enum.map(carriage_details, &occupancy_percentage_to_crowding_level(&1.occupancy_percentage))

    min_crowding_level = Enum.min(crowding_levels)

    relative_crowding_levels =
      for crowding_level <- crowding_levels do
        if crowding_level == min_crowding_level,
          do: :e,
          else: :f
      end

    {get_emptier_location(
       {Enum.count(relative_crowding_levels, &Kernel.==(&1, :e)), relative_crowding_levels}
     ), crowding_level_to_atom(min_crowding_level)}
  end

  defp get_crowding_description(_), do: nil

  defp occupancy_percentage_to_crowding_level(occupancy_percentage) do
    cond do
      occupancy_percentage <= 12 -> 1
      occupancy_percentage <= 40 -> 2
      occupancy_percentage > 40 -> 3
      occupancy_percentage == nil -> 4
    end
  end

  defp crowding_level_to_atom(crowding_level) do
    case crowding_level do
      1 -> :not_crowded
      2 -> :some_crowding
      3 -> :crowded
      4 -> :unknown_crowding
    end
  end

  defp get_emptier_location(car_crowding_levels) do
    case car_crowding_levels do
      {1, [_, _, :f, :f, :f, :f]} -> :front
      {1, [:f, :f, :f, :f, _, _]} -> :back
      {1, [:f, :f, _, _, :f, :f]} -> :middle
      {2, [_, _, _, :f, :f, :f]} -> :front
      {2, [_, :f, :f, _, :f, :f]} -> :front
      {2, [:f, :f, :f, _, _, _]} -> :back
      {2, [:f, :f, _, :f, :f, _]} -> :back
      {2, [_, _, :f, :f, _, _]} -> :front_and_back
      {2, _} -> :middle
      {3, [:f, _, _, _, _, :f]} -> :middle
      {3, [_, _, _, _, :f, :f]} -> :front
      {3, [:f, :f, _, _, _, _]} -> :back
      {3, [:f, _, :f, _, :f, _]} -> :train_level
      {3, [_, :f, _, :f, _, :f]} -> :train_level
      {3, _} -> :front_and_back
      {4, [:f, _, _, _, _, :f]} -> :middle
      {4, [_, _, _, _, _, :f]} -> :front
      {4, [_, _, _, :f, :f, _]} -> :front
      {4, [:f, _, _, _, _, _]} -> :back
      {4, [_, :f, :f, _, _, _]} -> :back
      {4, [_, _, :f, :f, _, _]} -> :front_and_back
      {4, _} -> :train_level
      {5, [_, _, _, _, _, :f]} -> :front
      {5, [:f, _, _, _, _, _]} -> :back
      {5, _} -> :train_level
      {6, _} -> :train_level
      _ -> :train_level
    end
  end

  @spec new_cars?(Locations.Location.t() | nil) :: boolean()
  defp new_cars?(nil) do
    false
  end

  defp new_cars?(%Locations.Location{
         multi_carriage_details: multi_carriage_details,
         route_id: route_id
       }) do
    Enum.any?(multi_carriage_details, fn carriage ->
      # See http://roster.transithistory.org/ for numbers of new cars
      case Integer.parse(carriage.label) do
        :error ->
          false

        {n, _remaining} ->
          route_id == "Red" and 1900 <= n and n <= 2151
      end
    end)
  end

  defimpl Content.Message do
    require Logger

    @width 18
    @boarding "BRD"
    @arriving "ARR"

    def to_string(%{
          destination: destination,
          minutes: minutes,
          approximate?: approximate?,
          prediction: %{stop_id: stop_id},
          station_code: station_code,
          zone: zone
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      duration_string =
        case minutes do
          :boarding -> @boarding
          :arriving -> @arriving
          :approaching -> "1 min"
          n -> "#{n}#{if approximate?, do: "+", else: ""} min"
        end

      track_number = Content.Utilities.stop_track_number(stop_id)

      cond do
        station_code == "RJFK" and destination == :alewife and zone == "m" ->
          platform_name = Content.Utilities.stop_platform_name(stop_id)

          {headsign_message, platform_message} =
            if is_integer(minutes) and minutes > 5 do
              {headsign, " (Platform TBD)"}
            else
              {headsign <> " (#{String.slice(platform_name, 0..0)})", " (#{platform_name} plat)"}
            end

          [
            {Content.Utilities.width_padded_string(
               headsign_message,
               "#{duration_string}",
               @width
             ), 6},
            {headsign <> platform_message, 6}
          ]

        track_number ->
          [
            {Content.Utilities.width_padded_string(headsign, duration_string, @width), 6},
            {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", @width), 6}
          ]

        true ->
          Content.Utilities.width_padded_string(headsign, duration_string, @width)
      end
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end
  end
end
