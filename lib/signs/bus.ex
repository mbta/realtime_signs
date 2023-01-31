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
    :prev_predictions
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
      prev_predictions: []
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
      max_minutes: max_minutes,
      sources: sources,
      config_engine: config_engine,
      prediction_engine: predictions_engine,
      prev_predictions: prev_predictions
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

    Stream.uniq_by(predictions, &{&1.route_id, &1.headsign})
    |> Stream.chunk_every(2, 2, [nil])
    |> Enum.map(&format_predictions(&1, current_time))
    |> IO.inspect()

    # Exclude missing headsign and/or display route (error?)

    # Special case: Hold prediction for inbound SL1 with stale prediction

    {:noreply, %{state | prev_predictions: predictions}}
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Bus unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  def schedule_run_loop(pid) do
    Process.send_after(pid, :run_loop, 1_000)
  end

  defp display_route(%{route_id: "746"}), do: "SLW"
  defp display_route(%{route_id: "749"}), do: "SL5"
  defp display_route(%{route_id: "751"}), do: "SL4"
  defp display_route(%{route_id: "743"}), do: "SL3"
  defp display_route(%{route_id: "742"}), do: "SL2"
  defp display_route(%{route_id: "741"}), do: "SL1"
  defp display_route(%{route_id: "77", headsign: "North Cambridge"}), do: "77A"

  defp display_route(%{route_id: "2427", stop_id: "185", headsign: headsign}) do
    cond do
      String.starts_with?(headsign, "Ashmont") -> "27"
      String.starts_with?(headsign, "Wakefield Av") -> "24"
      true -> "2427"
    end
  end

  defp display_route(%{route_id: route_id}), do: route_id

  defp prediction_minutes(prediction, current_time) do
    Timex.diff(prediction.departure_time, current_time, :minutes)
  end

  defp prediction_key(prediction) do
    Map.take(prediction, [:stop_id, :route_id, :vehicle_id, :direction_id])
  end

  defp format_predictions([first, second], current_time) do
    same = second && first.route_id == second.route_id && first.headsign == second.headsign

    for prediction <- [first, second] do
      if prediction do
        route = display_route(prediction)
        # If both predictions are for the same route, pad both lines based on the second line's
        # time string. That may use up extra space on the top line, but it means we'll choose
        # the same abbreviation for both, so the text will line up nicely.
        time =
          String.pad_leading(
            format_time(prediction, current_time),
            String.length(format_time(if(same, do: second, else: prediction), current_time))
          )

        dest_max = @line_max - String.length(route) - String.length(time) - 2

        # Choose the longest abbreviation that will fit within the remaining space.
        dest =
          (PaEss.Utilities.headsign_abbreviations(prediction.headsign) ++ [prediction.headsign])
          |> Enum.filter(&(String.length(&1) <= dest_max))
          |> Enum.max_by(&String.length/1, fn ->
            Logger.warn("No abbreviation for headsign: #{inspect(prediction.headsign)}")
            String.slice(prediction.headsign, 0, dest_max)
          end)
          |> String.pad_trailing(dest_max)

        "#{route} #{dest} #{time}"
      else
        ""
      end
    end
  end

  defp format_time(prediction, current_time) do
    case prediction_minutes(prediction, current_time) do
      0 -> "ARR"
      minutes -> "#{minutes} min"
    end
  end
end
