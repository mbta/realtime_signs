defmodule Sign.State do
  @moduledoc """
  Responsible for updating countdown signs based on the contents of TripUpdates.pb.

  Note that this assumes we're on the Mattapan line for now.
  """

  @three_minutes 60 * 3
  @ashmont_gtfs_id "70262"

  use GenServer

  require Logger

  alias Sign.Canned
  alias Sign.Message
  alias Sign.Content
  alias Sign.Stations
  alias Sign.Station

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Logger.info "Started Sign.State"
    {:ok, %{}}
  end

  @doc """
  Wipe the state clean.
  """
  def reset(pid \\ __MODULE__) do
    GenServer.call(pid, :reset)
  end

  @doc """
  Update signs based on a new TripUpdates.pb.
  """
  def update(pid \\ __MODULE__, trip_updates, vehicle_positions, current_time) do
    GenServer.call(pid, {:update, trip_updates, vehicle_positions, current_time})
  end

  def handle_call({:update, %GTFS.Realtime.FeedMessage{entity: trip_updates}, %GTFS.Realtime.FeedMessage{entity: vehicle_positions}, current_time}, _from, sign_state) do
    new_state = trip_updates
    |> get_next_predictions
    |> update_all(get_stopped_vehicles(vehicle_positions), sign_state, current_time)

    {:reply, :ok, new_state}
  end
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{}}
  end

  # Find all the trip/stop pairs that are currently STOPPED_AT a station.
  defp get_stopped_vehicles(vehicle_positions) do
    vehicle_positions
    |> Enum.filter(& &1.vehicle.current_status == :STOPPED_AT)
    |> MapSet.new(& {&1.vehicle.trip.trip_id, &1.vehicle.stop_id})
  end

  # Find the information to be display to be made at each enabled sign.
  defp get_next_predictions(feed_entities) do
    feed_entities
    |> gather_stop_time_updates
    |> group_by_sign
    |> sort_predictions
    |> limit_predictions
    |> Map.new
  end

  # Grab all the stop_time_updates and their related trips out of the TripUpdates info.
  defp gather_stop_time_updates(feed_entities) do
    Enum.flat_map(
      feed_entities,
      fn entity ->
        Enum.map(entity.trip_update.stop_time_update, & {&1, entity.trip_update.trip})
      end
    )
  end

  # Group updates by which sign they should be displayed at.
  defp group_by_sign(predictions) do
    Enum.group_by(
      predictions,
      fn {stop_time_update, trip} ->
        direction_id = trip.direction_id
        case Stations.pa_info(stop_time_update.stop_id) do
          nil -> nil
          %Station{display_type: :combined, stop_id: stop_id, zones: zones} -> {stop_id, zones[direction_id], display_line(direction_id)}
          %Station{display_type: {:one_line, line}, stop_id: stop_id, zones: zones} -> {stop_id, zones[direction_id], line}
          %Station{display_type: :separate, stop_id: stop_id, zones: zones} -> {stop_id, zones[direction_id]}
        end
      end
    )
    |> Map.delete(nil) # filter out disabled signs
  end

  # Which line to display a prediction on, based on its direction_id.
  defp display_line(0), do: :top
  defp display_line(1), do: :bottom

  # Sort predictions by time.
  defp sort_predictions(predictions_map) do
    Enum.map(
      predictions_map,
      fn {sign_info, predictions} ->
        {sign_info, Enum.sort_by(predictions, & elem(&1, 0).arrival.time)}
      end
    )
  end

  # Only take the first one or two predictions, depending on how many
  # sign lines are available to display them.
  defp limit_predictions(predictions) do
    Enum.map(
      predictions,
      fn {sign_info, predictions} ->
        case sign_info do
          {_stop_id, _zone} -> {sign_info, Enum.take(predictions, 2)} # separate predictions, display two per sign
          _ -> {sign_info, Enum.take(predictions, 1)}
        end
      end
    )
  end

  # Send all sign updates.
  defp update_all(signs, stopped_vehicles, sign_state, current_time) do
    Enum.reduce(signs, sign_state, fn ({sign_info, predictions}, acc) ->
      Map.merge(acc, update_sign(sign_info, predictions, stopped_vehicles, acc, current_time))
    end)
  end

  # Update a single two-line sign (if necessary).
  defp update_sign({pa_stop_id, platform} = sign_info, predictions, stopped_vehicles, sign_state, current_time) do
    all_messages = predictions
    |> List.insert_at(-1, nil)
    |> Enum.zip(1..2)
    |> Enum.map(& prediction_message(&1, stopped_vehicles, pa_stop_id, platform, current_time))

    messages = Enum.map(all_messages, & elem(&1, 0))
    {_, {arriving_announcement, arriving_trip}, _} = Enum.find(all_messages, {nil, {nil, nil}, nil}, & elem(&1, 1) != nil)
    {_, _, {countdown_announcement, countdown_trip}} = Enum.find(all_messages, {nil, nil, {nil, nil}}, & elem(&1, 2))

    previous_sign_state = Map.get(
      sign_state,
      sign_info,
      %{last_refreshed: current_time, messages: nil, last_arrival: nil, last_countdown: nil}
    )
    current_sign_state = %{
      last_refreshed: current_time,
      messages: messages,
      last_arrival: arriving_trip || previous_sign_state.last_arrival,
      last_countdown: countdown_trip || previous_sign_state.last_countdown,
    }

    new_sign_state = do_update_sign(
      messages,
      arriving_announcement,
      countdown_announcement,
      pa_stop_id,
      current_sign_state,
      previous_sign_state,
      current_time
    )

    %{sign_info => new_sign_state}
  end
  # Update a single one-line sign (if necessary).
  defp update_sign({pa_stop_id, platform, line} = sign_info, [prediction], stopped_vehicles, sign_state, current_time) do
    {message, {arriving_announcement, arriving_trip}, {countdown_announcement, countdown_trip}} = prediction_message(
      {prediction, line},
      stopped_vehicles,
      pa_stop_id,
      platform,
      current_time
    )

    previous_sign_state = Map.get(
      sign_state,
      sign_info,
      %{last_refreshed: current_time, messages: nil, last_arrival: nil, last_countdown: nil}
    )
    current_sign_state = %{
      last_refreshed: current_time,
      messages: [message],
      last_arrival: arriving_trip || previous_sign_state.last_arrival,
      last_countdown: countdown_trip || previous_sign_state.last_countdown
    }

    new_sign_state = do_update_sign(
      [message],
      arriving_announcement,
      countdown_announcement,
      pa_stop_id,
      current_sign_state,
      previous_sign_state,
      current_time
    )

    %{sign_info => new_sign_state}
  end

  # Actually perform the update.
  defp do_update_sign(messages, arriving_announcement, countdown_announcement, pa_stop_id, current_sign_state, previous_sign_state, current_time) do
    if needs_refresh?(current_sign_state, previous_sign_state) do
      Logger.info("#{pa_stop_id} :: #{inspect messages}")

      Content.new
      |> Content.station(pa_stop_id)
      |> Content.messages(messages)
      |> request(current_time)

      cond do
        arriving_announcement != nil and current_sign_state.last_arrival != previous_sign_state.last_arrival ->
          request(arriving_announcement, current_time)
        countdown_announcement != nil and current_sign_state.last_countdown != previous_sign_state.last_countdown ->
          request(countdown_announcement, current_time)
        true -> nil
      end

      current_sign_state
    else
      previous_sign_state
    end
  end

  # A sign should be refreshed if the content has changed, or if it's
  # been three minutes (with some allowance for lag) since the last
  # time it was refreshed.
  defp needs_refresh?(current_sign_state, previous_sign_state) do
    new_message? = current_sign_state.messages != previous_sign_state.messages
    message_expired? = Timex.diff(current_sign_state.last_refreshed, previous_sign_state.last_refreshed, :seconds) >= @three_minutes - 30

    new_message? or message_expired?
  end

  # Get the content to show on the sign.
  defp prediction_message({nil, line}, _stopped_vehicles, _pa_stop_id, platform, _current_time) do
    {clear_line(platform, line), nil, nil}
  end
  defp prediction_message({{stop_time_update, trip}, line}, stopped_vehicles, pa_stop_id, platform, current_time) do
    stop_id = stop_time_update.stop_id
    key = {trip.trip_id, stop_id}
    prediction_time = if MapSet.member?(stopped_vehicles, key) do
      :boarding
    else
      time(stop_time_update, current_time)
    end

    message = Message.new
    |> Message.placement(platform, line)
    |> Message.erase_after(expiration_time(prediction_time))
    |> Message.message(message(Message.headsign(trip.direction_id, trip.route_id, stop_id), prediction_time, stop_id))

    arriving_announcement = if announce_arriving?(prediction_time) do
      {arriving_announcement(pa_stop_id, stop_id, trip.direction_id, platform), trip.trip_id}
    else
      {nil, nil}
    end

    countdown_announcement = if announce_countdown?(prediction_time) do
      {countdown_announcement(pa_stop_id, stop_id, trip.direction_id, platform, prediction_time), trip.trip_id}
    else
      {nil, nil}
    end

    {message, arriving_announcement, countdown_announcement}
  end

  defp expiration_time(:boarding), do: 10
  defp expiration_time(0), do: 30
  defp expiration_time(_), do: @three_minutes

  defp announce_arriving?(prediction_time) do
    prediction_time == 0
  end

  defp announce_countdown?(prediction_time) when is_integer(prediction_time) do
    prediction_time != 0 and Integer.mod(prediction_time, 4) == 0 and prediction_time <= 20
  end
  defp announce_countdown?(_), do: false

  def request(payload, current_time) do
    unless Map.get(payload, :station) == "MMIL" do
      sign_updater().request(payload, current_time)
    end
  end

  defp sign_updater() do
    Application.get_env(:realtime_signs, :sign_updater)
  end

  def message(headsign_msg, :boarding, stop_id) do
    do_message(headsign_msg, "BRD", stop_id)
  end
  def message(headsign_msg, 0, stop_id) do
    do_message(headsign_msg, "ARR", stop_id)
  end
  def message(headsign_msg, time, stop_id) when time > 20 do
    do_message(headsign_msg, "20+ min", stop_id)
  end
  def message(headsign_msg, time, stop_id) do
    do_message(headsign_msg, "#{time} min", stop_id)
  end

  defp do_message(headsign_msg, time_msg, stop_id) do
    padding = Content.sign_width() - (String.length(headsign_msg) + String.length(time_msg))
    # Hack to correctly align Ashmont sign with HRRT's message
    padding = if stop_id == @ashmont_gtfs_id do
      padding - 3
    else
      padding
    end
    "#{headsign_msg}#{String.duplicate(" ", padding)}#{time_msg}"
  end

  defp arriving_announcement(pa_stop_id, gtfs_stop_id, direction_id, platform) do
    announcement = Canned.new
    |> Canned.mid(arriving_message_id(direction_id, gtfs_stop_id))
    |> Canned.station(pa_stop_id)
    |> Canned.type(:audio)
    |> Canned.platforms(platform)

    announcement
  end

  defp countdown_announcement(pa_stop_id, gtfs_stop_id, direction_id, platform, time) do
    announcement = Canned.new
    |> Canned.mid(countdown_message_id())
    |> Canned.station(pa_stop_id)
    |> Canned.platforms(platform)
    |> Canned.type(:audio)
    |> Canned.variables([destination_var(direction_id, gtfs_stop_id), arrival_var(), time_var(time)])

    announcement
  end

  defp arriving_message_id(0, _), do: 90128
  defp arriving_message_id(1, @ashmont_gtfs_id), do: 90128 # Special case for Ashmont since it's a terminal
  defp arriving_message_id(1, _), do: 90129

  defp countdown_message_id(), do: 90

  defp arrival_var(), do: 503

  defp destination_var(0, _), do: 4100 # Mattapan
  defp destination_var(1, @ashmont_gtfs_id), do: 4100 # Special case for Ashmont since it's a terminal
  defp destination_var(1, _), do: 4016 # Ashmont

  defp time_var(time) do
    5000 + time
  end

  defp time(stop_time_update, current_time) do
    seconds = stop_time_update.arrival.time
    |> Timex.from_unix
    |> Timex.diff(current_time, :seconds)

    round(seconds/60)
  end

  defp clear_line(platform, line) do
    Message.new
    |> Message.placement(platform, line)
    |> Message.message(:blank)
  end
end
