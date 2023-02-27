defmodule Signs.Bus do
  use GenServer
  require Logger

  @line_max 18
  @var_max 30
  @drawbridge_minutes "135"
  @drawbridge_soon "136"
  @drawbridge_minutes_spanish "152"
  @drawbridge_soon_spanish "157"

  @enforce_keys [
    :id,
    :pa_ess_loc,
    :text_zone,
    :audio_zones,
    :max_minutes,
    :sources,
    :top_sources,
    :bottom_sources,
    :chelsea_bridge,
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
      sources: parse_sources(sign["sources"]),
      top_sources: parse_sources(sign["top_sources"]),
      bottom_sources: parse_sources(sign["bottom_sources"]),
      chelsea_bridge: sign["chelsea_bridge"],
      config_engine: opts[:config_engine] || Engine.Config,
      prediction_engine: opts[:prediction_engine] || Engine.BusPredictions,
      prev_predictions: [],
      current_content: {nil, nil},
      last_update: nil
    }

    GenServer.start_link(__MODULE__, state)
  end

  defp parse_sources(nil), do: nil

  defp parse_sources(sources) do
    for source <- sources do
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
    end
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
      top_sources: top_sources,
      bottom_sources: bottom_sources,
      chelsea_bridge: chelsea_bridge,
      config_engine: config_engine,
      prediction_engine: predictions_engine,
      prev_predictions: prev_predictions,
      current_content: current_content,
      last_update: last_update
    } = state

    config = config_engine.sign_config(id)
    chelsea_bridge_status = Engine.ChelseaBridge.bridge_status()
    current_time = Timex.now()

    prev_predictions_lookup =
      for prediction <- prev_predictions,
          into: %{} do
        {prediction_key(prediction), prediction}
      end

    fetch_predictions = fn source_list ->
      for %{stop_id: stop_id, routes: routes} <- source_list,
          prediction <- predictions_engine.predictions_for_stop(stop_id),
          Map.take(prediction, [:route_id, :direction_id]) in routes do
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
    end

    [predictions, top_predictions, bottom_predictions] =
      for source_list <- [sources, top_sources, bottom_sources] do
        if source_list, do: fetch_predictions.(source_list), else: []
      end

    inject_bridge_message = fn pairs ->
      if chelsea_bridge == "audio_visual" &&
           bridge_status_raised?(chelsea_bridge_status, current_time) do
        mins = bridge_status_minutes(chelsea_bridge_status, current_time)

        line2 =
          case {mins > 0, predictions != []} do
            {true, true} -> "SL3 delays #{mins} more min"
            {true, false} -> "for #{mins} more minutes"
            {false, true} -> "Expect SL3 delays"
            {false, false} -> ""
          end

        Enum.take(pairs, 1) ++ [["Drawbridge is up", line2]]
      else
        pairs
      end
    end

    bridge_audio =
      if chelsea_bridge && bridge_status_raised?(chelsea_bridge_status, current_time) do
        case bridge_status_minutes(chelsea_bridge_status, current_time) do
          minutes when minutes < 2 ->
            [{@drawbridge_soon, []}, {@drawbridge_soon_spanish, []}]

          minutes ->
            [
              {@drawbridge_minutes, [PaEss.Utilities.number_var(minutes, :english)]},
              {@drawbridge_minutes_spanish, [PaEss.Utilities.number_var(minutes, :spanish)]}
            ]
        end
        |> Enum.map(fn {msg, vars} ->
          %Content.Audio.BusPredictions{message: {:canned, {msg, vars, :audio_visual}}}
        end)
      else
        []
      end

    {[top, bottom], _audio} =
      cond do
        config == :off ->
          {[Content.Message.Empty.new(), Content.Message.Empty.new()], []}

        match?({:static_text, _}, config) ->
          {_, {line1, line2}} = config

          content =
            [[line1, line2]]
            |> inject_bridge_message.()
            |> paginate_pairs()

          audio =
            [%Content.Audio.Custom{message: "#{line1} #{line2}"}]
            |> Enum.concat(bridge_audio)

          {content, audio}

        # Special case: 71 and 73 buses board on the Harvard upper busway at certain times. If
        # they are predicted there, let people on the lower busway know.
        id == "bus.Harvard_lower" &&
            Enum.any?(
              predictions_engine.predictions_for_stop("20761"),
              &(&1.route_id in ["71", "73"])
            ) ->
          content = [
            Content.Message.Custom.new("Board routes 71", :top),
            Content.Message.Custom.new("and 73 on upper level", :bottom)
          ]

          audio = paginate_audio([:board_routes_71_and_73_on_upper_level])
          {content, audio}

        sources ->
          # Platform mode. Display one prediction per route, but if all the predictions are for the
          # same route, then show a single page of two.
          {selected_predictions, one_route?} =
            case Enum.uniq_by(predictions, &route_key(&1)) do
              [_] -> {Enum.take(predictions, 2), true}
              list -> {list, false}
            end

          content =
            selected_predictions
            |> Stream.chunk_every(2, 2, [nil])
            |> Stream.map(fn [first, second] ->
              [
                format_prediction(first, second, current_time),
                format_prediction(second, first, current_time)
              ]
            end)
            |> inject_bridge_message.()
            |> paginate_pairs()

          audio =
            if one_route? do
              selected_predictions
              |> Enum.zip_with([:next, :following], &long_prediction_audio(&1, current_time, &2))
            else
              # TODO departures? SL special preamble?
              selected_predictions
              |> Enum.map(&prediction_audio(&1, current_time))
              |> List.insert_at(0, [:upcoming_arrivals])
            end
            |> Stream.intersperse([:_])
            |> Stream.concat()
            |> paginate_audio()
            |> Enum.concat(bridge_audio)

          {content, audio}

        true ->
          # Mezzanine mode. Display and paginate each line separately.
          [selected_top_predictions, selected_bottom_predictions] =
            for predictions_list <- [top_predictions, bottom_predictions] do
              Enum.uniq_by(predictions_list, &route_key(&1))
            end

          content =
            for prediction_list <- [selected_top_predictions, selected_bottom_predictions] do
              prediction_list
              |> Enum.map(&format_prediction(&1, nil, current_time))
              |> paginate_message()
            end

          # TODO departures? SL special preamble?
          audio =
            (selected_top_predictions ++ selected_bottom_predictions)
            |> Enum.map(&prediction_audio(&1, current_time))
            |> List.insert_at(0, [:upcoming_arrivals])
            |> Stream.intersperse([:_])
            |> Stream.concat()
            |> paginate_audio()
            |> Enum.concat(bridge_audio)

          {content, audio}
      end

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

    {:noreply,
     %{
       new_state
       | prev_predictions: Enum.concat([predictions, top_predictions, bottom_predictions])
     }}
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

  defp bridge_status_minutes(bridge_status, current_time) do
    round(Timex.diff(bridge_status.estimate, current_time, :seconds) / 60)
  end

  defp bridge_status_raised?(bridge_status, current_time) do
    # If the estimate is more than 30 mins ago, assume someone forgot to reset the status,
    # and treat the bridge as lowered.
    bridge_status.raised? && bridge_status_minutes(bridge_status, current_time) < -30
  end

  defp route_key(prediction) do
    {PaEss.Utilities.prediction_route_name(prediction), prediction.headsign}
  end

  defp format_prediction(nil, _, _), do: ""

  defp format_prediction(prediction, other, current_time) do
    %{headsign: headsign} = prediction

    other_route_length = if other, do: String.length(format_route(other)), else: 0

    route =
      case format_route(prediction) do
        "" -> ""
        str -> String.pad_trailing(str, other_route_length)
      end

    # If both predictions are for the same route, but the times are different sizes, we could
    # end up using different abbreviations on the same page, e.g. "SouthSta" and "So Sta".
    # To avoid that, format both times using the other one's potentially larger size. That
    # may waste one space on the top line, but will ensure that the abbreviations match up.
    other_time_length =
      case other do
        %{headsign: ^headsign} -> String.length(format_time(other, current_time))
        _ -> 0
      end

    time = String.pad_leading(format_time(prediction, current_time), other_time_length)

    dest_max = @line_max - String.length(route) - String.length(time) - 1

    # Choose the longest abbreviation that will fit within the remaining space.
    dest =
      [headsign | PaEss.Utilities.headsign_abbreviations(headsign)]
      |> Enum.filter(&(String.length(&1) <= dest_max))
      |> Enum.max_by(&String.length/1, fn ->
        Logger.warn("No abbreviation for headsign: #{inspect(headsign)}")
        headsign
      end)

    Content.Utilities.width_padded_string("#{route}#{dest}", time, @line_max)
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

  defp paginate_message(pages) do
    message =
      case pages do
        [] -> ""
        [s] -> s
        _ -> for s <- pages, do: {s, 6}
      end

    %Content.Message.BusPredictions{message: message}
  end

  defp paginate_pairs(pairs) do
    [
      paginate_message(for [x, _] <- pairs, do: x),
      paginate_message(for [_, x] <- pairs, do: x)
    ]
  end

  defp prediction_audio(prediction, current_time) do
    route =
      case PaEss.Utilities.prediction_route_name(prediction) do
        nil -> []
        str -> [{:route, str}]
      end

    dest = [{:headsign, prediction.headsign}]

    time =
      case prediction_minutes(prediction, current_time) do
        0 -> [:arriving]
        1 -> [{:minutes, 1}, :minute]
        m -> [{:minutes, m}, :minutes]
      end

    Enum.concat([route, dest, time])
  end

  defp long_prediction_audio(prediction, current_time, next_or_following) do
    preamble =
      case next_or_following do
        :next -> [:the_next_bus_to]
        # TODO: route? SL speacial handling?
        :following -> [:the_following_bus_to]
      end

    dest = [{:headsign, prediction.headsign}]

    time =
      case prediction_minutes(prediction, current_time) do
        0 -> [:is_now_arriving]
        1 -> [:arrives, :in, {:minutes, 1}, :minute]
        m -> [:arrives, :in, {:minutes, m}, :minutes]
      end

    Enum.concat([preamble, dest, time])
  end

  defp paginate_audio(items) do
    for item <- items do
      PaEss.Utilities.audio_take(item) ||
        (
          Logger.error("No audio for: #{inspect(item)}")
          PaEss.Utilities.audio_take(:_)
        )
    end
    |> Stream.chunk_every(@var_max)
    |> Enum.map(fn vars ->
      %Content.Audio.BusPredictions{
        message: {:canned, {PaEss.Utilities.take_message_id(vars), vars, :audio}}
      }
    end)
  end
end
