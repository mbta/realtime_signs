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

  @max_time Content.Utilities.max_time_seconds()
  @terminal_brd_seconds 30
  @terminal_prediction_offset_seconds -60

  @enforce_keys [:destination, :minutes]
  defstruct [
    :destination,
    :minutes,
    :route_id,
    :station_code,
    :stop_id,
    :trip_id,
    :direction_id,
    :zone,
    width: 18,
    platform: nil,
    new_cars?: false,
    terminal?: false,
    certainty: nil,
    crowding_data_confidence: nil
  ]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          minutes: integer() | :boarding | :arriving | :approaching | :max_time,
          route_id: String.t(),
          stop_id: String.t(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          direction_id: 0 | 1,
          width: integer(),
          new_cars?: boolean(),
          station_code: String.t() | nil,
          zone: String.t() | nil,
          platform: Content.platform() | nil,
          terminal?: boolean(),
          certainty: non_neg_integer() | nil,
          crowding_data_confidence: :high | :low | nil
        }

  @spec non_terminal(
          Predictions.Prediction.t(),
          String.t(),
          String.t(),
          Content.platform() | nil,
          integer()
        ) :: t() | nil
  def non_terminal(prediction, station_code, zone, platform \\ nil, width \\ 18)

  def non_terminal(prediction, station_code, zone, platform, width) do
    # e.g., North Station which is non-terminal but has trips that begin there
    predicted_time = prediction.seconds_until_arrival || prediction.seconds_until_departure

    certainty =
      if prediction.seconds_until_arrival,
        do: prediction.arrival_certainty,
        else: prediction.departure_certainty

    minutes =
      cond do
        prediction.stops_away == 0 -> :boarding
        predicted_time <= 30 -> :arriving
        predicted_time <= 60 -> :approaching
        predicted_time >= @max_time -> :max_time
        true -> predicted_time |> Kernel./(60) |> round()
      end

    crowding_data_confidence =
      calculate_crowding_data_confidence(
        prediction,
        Engine.Locations.for_vehicle(prediction.vehicle_id)
      )

    # TODO: Calculate crowding data classification and pass that along as well

    case Content.Utilities.destination_for_prediction(
           prediction.route_id,
           prediction.direction_id,
           prediction.destination_stop_id
         ) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
          minutes: minutes,
          route_id: prediction.route_id,
          stop_id: prediction.stop_id,
          trip_id: prediction.trip_id,
          direction_id: prediction.direction_id,
          width: width,
          new_cars?: prediction.new_cars?,
          station_code: station_code,
          zone: zone,
          platform: platform,
          certainty: certainty,
          crowding_data_confidence: crowding_data_confidence
        }

      {:error, _} ->
        Logger.warn("no_destination_for_prediction #{inspect(prediction)}")
        nil
    end
  end

  @spec terminal(Predictions.Prediction.t(), integer()) :: t() | nil
  def terminal(prediction, width \\ 18)

  def terminal(prediction, width) do
    stopped_at? = prediction.stops_away == 0

    minutes =
      case prediction.seconds_until_departure + @terminal_prediction_offset_seconds do
        x when x <= @terminal_brd_seconds and stopped_at? -> :boarding
        x when x <= @terminal_brd_seconds -> 1
        x when x >= @max_time -> :max_time
        x -> x |> Kernel./(60) |> round()
      end

    case Content.Utilities.destination_for_prediction(
           prediction.route_id,
           prediction.direction_id,
           prediction.destination_stop_id
         ) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
          minutes: minutes,
          route_id: prediction.route_id,
          stop_id: prediction.stop_id,
          trip_id: prediction.trip_id,
          direction_id: prediction.direction_id,
          width: width,
          new_cars?: prediction.new_cars?,
          terminal?: true,
          certainty: prediction.departure_certainty
        }

      {:error, _} ->
        Logger.warn("no_destination_for_prediction #{inspect(prediction)}")
        nil
    end
  end

  defp calculate_crowding_data_confidence(_prediction, nil), do: nil

  defp calculate_crowding_data_confidence(prediction, location)
       when prediction.route_id in ["Orange"] and location.stop_id == prediction.stop_id do
    if location.status in [:incoming_at, :in_transit_to],
      do: :high,
      else: :low
  end

  defp calculate_crowding_data_confidence(_prediction, _location), do: nil

  defimpl Content.Message do
    require Logger

    @boarding "BRD"
    @arriving "ARR"
    @max_time "20+ min"

    def to_string(%{
          destination: destination,
          minutes: minutes,
          width: width,
          stop_id: stop_id,
          station_code: station_code,
          zone: zone
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      duration_string =
        case minutes do
          :boarding -> @boarding
          :arriving -> @arriving
          :approaching -> "1 min"
          :max_time -> @max_time
          n -> "#{n} min"
        end

      track_number = Content.Utilities.stop_track_number(stop_id)

      cond do
        station_code == "RJFK" and destination == :alewife and zone == "m" ->
          platform_name = Content.Utilities.stop_platform_name(stop_id)

          {headsign_message, platform_message} =
            if minutes == :max_time or (is_integer(minutes) and minutes > 5) do
              {headsign, " (Platform TBD)"}
            else
              {headsign <> " (#{String.slice(platform_name, 0..0)})", " (#{platform_name} plat)"}
            end

          [
            {Content.Utilities.width_padded_string(
               headsign_message,
               "#{duration_string}",
               width
             ), 6},
            {headsign <> platform_message, 6}
          ]

        track_number ->
          [
            {Content.Utilities.width_padded_string(headsign, duration_string, width), 6},
            {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", width), 6}
          ]

        true ->
          Content.Utilities.width_padded_string(headsign, duration_string, width)
      end
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end
  end
end
