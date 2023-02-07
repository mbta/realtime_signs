defmodule Signs.Bus do
  use GenServer
  require Logger

  @line_max 18

  @enforce_keys [
    :id,
    :pa_ess_loc,
    :text_zone,
    :audio_zones,
    :max_minutes,
    :sources,
    :config_engine,
    :prediction_engine,
    :prev_predictions,
    :current_content,
    :last_update
  ]
  defstruct @enforce_keys

  def start_link(sign, opts \\ []) do
    state = %__MODULE__{
      id: Map.fetch!(sign, "id"),
      pa_ess_loc: Map.fetch!(sign, "pa_ess_loc"),
      text_zone: Map.fetch!(sign, "text_zone"),
      audio_zones: Map.fetch!(sign, "audio_zones"),
      max_minutes: Map.fetch!(sign, "max_minutes"),
      sources:
        for source <- Map.fetch!(sign, "sources") do
          %{
            stop_id: Map.fetch!(source, "stop_id"),
            routes:
              for route <- Map.fetch!(source, "routes") do
                %{
                  route_id: Map.fetch!(route, "route_id"),
                  direction_id: Map.fetch!(route, "direction_id")
                }
              end
          }
        end,
      config_engine: opts[:config_engine] || Engine.Config,
      prediction_engine: opts[:prediction_engine] || Engine.BusPredictions,
      prev_predictions: [],
      current_content: {nil, nil},
      last_update: nil
    }

    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    schedule_run_loop(self())
    {:ok, state}
  end

  def handle_info(:run_loop, state) do
    schedule_run_loop(self())

    %__MODULE__{
      id: id,
      pa_ess_loc: pa_ess_loc,
      text_zone: text_zone,
      max_minutes: max_minutes,
      sources: sources,
      config_engine: config_engine,
      prediction_engine: predictions_engine,
      prev_predictions: prev_predictions,
      current_content: current_content,
      last_update: last_update
    } = state

    _config = config_engine.sign_config(id)
    current_time = Timex.now()

    prev_predictions_lookup =
      for prediction <- prev_predictions,
          into: %{} do
        {prediction_key(prediction), prediction}
      end

    predictions =
      for %{stop_id: stop_id, routes: routes} <- sources,
          prediction <- predictions_engine.predictions_for_stop(stop_id),
          Enum.any?(
            routes,
            &(&1.route_id == prediction.route_id && &1.direction_id == prediction.direction_id)
          ) do
        prediction
      end
      # Exclude predictions whose times are missing or out of bounds
      |> Stream.reject(
        &(!&1.departure_time ||
            Timex.before?(&1.departure_time, Timex.shift(current_time, seconds: -5)) ||
            Timex.after?(&1.departure_time, Timex.shift(current_time, minutes: max_minutes)))
      )
      # Special cases:
      # Exclude 89.2 OB to Davis
      # Exclude routes terminating at Braintree (230.4 IB, 236.3 OB)
      # Exclude routes terminating at Mattapan, in case those variants of route 24 come back.
      |> Stream.reject(
        &((&1.stop_id == "5104" && String.starts_with?(&1.headsign, "Davis")) ||
            (&1.stop_id == "38671" && String.starts_with?(&1.headsign, "Braintree")) ||
            (&1.stop_id in ["185", "18511"] && String.starts_with?(&1.headsign, "Mattapan")))
      )
      |> Stream.map(fn prediction ->
        prev = prev_predictions_lookup[prediction_key(prediction)]

        # If the new prediction would count up by 1 minute from the last, just keep the old one
        departure_time =
          if prev &&
               prediction_minutes(prediction, current_time) ==
                 prediction_minutes(prev, current_time) + 1 do
            prev.departure_time
          else
            prediction.departure_time
          end

        %{prediction | departure_time: departure_time}
      end)
      |> Enum.sort_by(& &1.departure_time)

    # Normally display one prediction per route, but if all the predictions are for the same
    # route, then show a single page of two.
    [top, bottom] =
      case Enum.uniq_by(predictions, &{PaEss.Utilities.prediction_route_name(&1), &1.headsign}) do
        [_] -> Enum.take(predictions, 2)
        list -> list
      end
      |> Stream.chunk_every(2, 2, [nil])
      |> Stream.map(&format_predictions(&1, current_time))
      |> Enum.zip()
      |> case do
        [] -> [{}, {}]
        [_, _] = list -> list
      end
      |> Enum.map(fn pages ->
        message =
          case pages do
            {} -> ""
            {s} -> s
            _ -> for s <- Tuple.to_list(pages), do: {s, 6}
          end

        %Content.Message.BusPredictions{message: message}
      end)

    # Update the sign if:
    # 1. it has never been updated before (we just booted up)
    # 2. the sign is about to auto-blank, so refresh it
    # 3. the content has changed, but wait until the existing content has paged at least once
    should_update =
      !last_update ||
        Timex.after?(current_time, Timex.shift(last_update, seconds: 150)) ||
        (current_content != {top, bottom} &&
           Timex.after?(
             current_time,
             Timex.shift(last_update, seconds: Content.Utilities.content_duration(current_content))
           ))

    new_state =
      if should_update do
        MessageQueue.update_sign({pa_ess_loc, text_zone}, top, bottom, 180, :now)
        %{state | current_content: {top, bottom}, last_update: current_time}
      else
        state
      end

    # Exclude missing headsign and/or display route (error?)

    # Special case: Hold prediction for inbound SL1 with stale prediction

    {:noreply, %{new_state | prev_predictions: predictions}}
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Bus unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  def schedule_run_loop(pid) do
    Process.send_after(pid, :run_loop, 1_000)
  end

  defp prediction_minutes(prediction, current_time) do
    round(Timex.diff(prediction.departure_time, current_time, :seconds) / 60)
  end

  defp prediction_key(prediction) do
    Map.take(prediction, [:stop_id, :route_id, :vehicle_id, :direction_id])
  end

  defp format_predictions([first, second], current_time) do
    same = second && first.headsign == second.headsign

    max_route_length =
      for prediction <- [first, second], prediction do
        String.length(format_route(prediction))
      end
      |> Enum.max()

    for prediction <- [first, second] do
      if prediction do
        route =
          case format_route(prediction) do
            "" -> ""
            str -> String.pad_trailing(str, max_route_length)
          end

        # If both predictions are for the same route, but the times are different sizes, we could
        # end up using different abbreviations on the same page, e.g. "SouthSta" and "So Sta".
        # To avoid that, format both times using the second one's potentially larger size. That
        # may waste one space on the top line, but will ensure that the abbreviations match up.
        time =
          String.pad_leading(
            format_time(prediction, current_time),
            String.length(format_time(if(same, do: second, else: prediction), current_time))
          )

        dest_max = @line_max - String.length(route) - String.length(time) - 1

        # Choose the longest abbreviation that will fit within the remaining space.
        dest =
          [prediction.headsign | PaEss.Utilities.headsign_abbreviations(prediction.headsign)]
          |> Enum.filter(&(String.length(&1) <= dest_max))
          |> Enum.max_by(&String.length/1, fn ->
            Logger.warn("No abbreviation for headsign: #{inspect(prediction.headsign)}")
            prediction.headsign
          end)

        Content.Utilities.width_padded_string("#{route}#{dest}", time, @line_max)
      else
        ""
      end
    end
  end

  defp format_route(prediction) do
    case PaEss.Utilities.prediction_route_name(prediction) do
      nil -> ""
      str -> "#{str} "
    end
  end

  defp format_time(prediction, current_time) do
    case prediction_minutes(prediction, current_time) do
      0 -> "ARR"
      minutes -> "#{minutes} min"
    end
  end
end
