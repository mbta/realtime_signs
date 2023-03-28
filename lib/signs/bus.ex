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
    :extra_audio_sources,
    :chelsea_bridge,
    :read_loop_interval,
    :read_loop_offset,
    :config_engine,
    :prediction_engine,
    :bridge_engine,
    :sign_updater,
    :prev_predictions,
    :prev_bridge_status,
    :current_messages,
    :last_update,
    :last_read_time
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
      extra_audio_sources: parse_sources(sign["extra_audio_sources"]),
      chelsea_bridge: sign["chelsea_bridge"],
      read_loop_interval: Map.fetch!(sign, "read_loop_interval"),
      read_loop_offset: Map.fetch!(sign, "read_loop_offset"),
      config_engine: opts[:config_engine] || Engine.Config,
      prediction_engine: opts[:prediction_engine] || Engine.BusPredictions,
      bridge_engine: opts[:bridge_engine] || Engine.ChelseaBridge,
      sign_updater: opts[:sign_updater] || MessageQueue,
      prev_predictions: [],
      prev_bridge_status: nil,
      current_messages: {nil, nil},
      last_update: nil,
      last_read_time: Timex.now()
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
      sources: sources,
      top_sources: top_sources,
      bottom_sources: bottom_sources,
      extra_audio_sources: extra_audio_sources,
      config_engine: config_engine,
      prediction_engine: prediction_engine,
      bridge_engine: bridge_engine,
      sign_updater: sign_updater,
      prev_predictions: prev_predictions
    } = state

    # Fetch the data we need to compute the updated sign content.
    config = config_engine.sign_config(id)
    bridge_enabled? = config_engine.chelsea_bridge_config() == :auto
    bridge_status = bridge_engine.bridge_status()
    current_time = Timex.now()

    prev_predictions_lookup =
      for prediction <- prev_predictions,
          into: %{} do
        {prediction_key(prediction), prediction}
      end

    {[predictions, top_predictions, bottom_predictions, extra_audio_predictions], all_predictions} =
      for source_list <- [sources, top_sources, bottom_sources, extra_audio_sources] do
        if source_list,
          do: fetch_predictions(source_list, prev_predictions_lookup, current_time, state),
          else: []
      end
      |> then(fn lists ->
        {Enum.map(lists, &filter_predictions(&1, current_time, state)), Enum.concat(lists)}
      end)

    # Compute new sign text and audio
    {[top, bottom], audios} =
      cond do
        config == :off ->
          {[Content.Message.Empty.new(), Content.Message.Empty.new()], []}

        match?({:static_text, _}, config) ->
          static_text_content(
            config,
            bridge_status,
            bridge_enabled?,
            current_time,
            predictions,
            state
          )

        # Special case: 71 and 73 buses board on the Harvard upper busway at certain times. If
        # they are predicted there, let people on the lower busway know.
        id == "bus.Harvard_lower" &&
            Enum.any?(
              prediction_engine.predictions_for_stop("20761"),
              &(&1.route_id in ["71", "73"])
            ) ->
          special_harvard_content()

        sources ->
          platform_mode_content(
            predictions,
            extra_audio_predictions,
            current_time,
            bridge_status,
            bridge_enabled?,
            state
          )

        true ->
          mezzanine_mode_content(
            top_predictions,
            bottom_predictions,
            current_time,
            bridge_status,
            bridge_enabled?,
            state
          )
      end

    # Update the sign (if appropriate), and record changes in state
    state
    |> then(fn state ->
      if should_update?({top, bottom}, current_time, state) do
        sign_updater.update_sign({pa_ess_loc, text_zone}, top, bottom, 180, :now)
        %{state | current_messages: {top, bottom}, last_update: current_time}
      else
        state
      end
    end)
    |> then(fn state ->
      if should_read?(current_time, state) do
        send_audio(audios, state)
        %{state | last_read_time: current_time}
      else
        if should_announce_drawbridge?(bridge_status, bridge_enabled?, current_time, state) do
          bridge_audio(bridge_status, bridge_enabled?, current_time, state)
          |> send_audio(state)
        end

        state
      end
    end)
    |> Map.put(:prev_predictions, all_predictions)
    |> Map.put(:prev_bridge_status, bridge_status)
    |> then(fn state -> {:noreply, state} end)
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Bus unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  def schedule_run_loop(pid) do
    Process.send_after(pid, :run_loop, 1_000)
  end

  defp fetch_predictions(source_list, prev_predictions_lookup, current_time, state) do
    %{prediction_engine: prediction_engine} = state

    for %{stop_id: stop_id, routes: routes} <- source_list,
        prediction <- prediction_engine.predictions_for_stop(stop_id),
        Map.take(prediction, [:route_id, :direction_id]) in routes,
        prediction.departure_time do
      prev = prev_predictions_lookup[prediction_key(prediction)]

      # Prediction times can sometimes jump around from one update to the next, so we adjust them
      # in certain cases. If the new prediction would count up by 1 minute, or would revive a
      # previously stale entry, just keep the old time.
      departure_time =
        if prev &&
             (prediction_minutes(prediction, current_time) ==
                prediction_minutes(prev, current_time) + 1 ||
                prediction_stale?(prev, current_time)) do
          prev.departure_time
        else
          prediction.departure_time
        end

      %{prediction | departure_time: departure_time}
    end
    |> Enum.sort_by(& &1.departure_time, DateTime)
  end

  defp filter_predictions(predictions, current_time, state) do
    %{max_minutes: max_minutes} = state

    predictions
    # Exclude predictions that are too old or too far in the future
    |> Stream.reject(
      &(prediction_stale?(&1, current_time) ||
          Timex.after?(&1.departure_time, Timex.shift(current_time, minutes: max_minutes)))
    )
    # Special cases:
    # Exclude 89.2 OB to Davis
    # Exclude routes terminating at Braintree (230.4 IB, 236.3 OB)
    # Exclude routes terminating at Mattapan, in case those variants of route 24 come back.
    |> Enum.reject(
      &((&1.stop_id == "5104" && String.starts_with?(&1.headsign, "Davis")) ||
          (&1.stop_id == "38671" && String.starts_with?(&1.headsign, "Braintree")) ||
          (&1.stop_id in ["185", "18511"] && String.starts_with?(&1.headsign, "Mattapan")))
    )
  end

  # Static text mode. Just display the configured text, and possibly the bridge message.
  defp static_text_content(
         config,
         bridge_status,
         bridge_enabled?,
         current_time,
         predictions,
         state
       ) do
    {_, {line1, line2}} = config

    messages =
      [[line1, line2]]
      |> Enum.concat(
        bridge_message(bridge_status, bridge_enabled?, current_time, predictions, state)
      )
      |> paginate_pairs()

    audios =
      [%Content.Audio.Custom{message: "#{line1} #{line2}"}]
      |> Enum.concat(bridge_audio(bridge_status, bridge_enabled?, current_time, state))

    {messages, audios}
  end

  # Platform mode. Display one prediction per route, but if all the predictions are for the
  # same route, then show a single page of two.
  defp platform_mode_content(
         predictions,
         extra_audio_predictions,
         current_time,
         bridge_status,
         bridge_enabled?,
         state
       ) do
    messages =
      case Enum.uniq_by(predictions, &route_key(&1)) do
        [_] -> Enum.take(predictions, 2)
        list -> list
      end
      |> Stream.chunk_every(2, 2, [nil])
      |> Stream.map(fn [first, second] ->
        [
          format_prediction(first, second, current_time),
          format_prediction(second, first, current_time)
        ]
      end)
      |> Enum.concat(
        bridge_message(bridge_status, bridge_enabled?, current_time, predictions, state)
      )
      |> paginate_pairs()

    # Special case: Nubian platform E has two separate text zones, but only one audio zone due
    # to close proximity. One sign process is configured to read out the other sign's prediction
    # list in addition to its own, while the other one stays silent.
    audio_predictions = predictions ++ extra_audio_predictions

    audios =
      case Enum.uniq_by(audio_predictions, &route_key(&1)) do
        [_] ->
          Enum.take(audio_predictions, 2)
          |> Enum.zip_with([:next, :following], &long_prediction_audio(&1, current_time, &2))

        list ->
          Enum.map(list, &prediction_audio(&1, current_time))
          |> add_preamble()
      end
      |> Stream.intersperse([:_])
      |> Stream.concat()
      |> paginate_audio()
      |> Enum.concat(bridge_audio(bridge_status, bridge_enabled?, current_time, state))

    {messages, audios}
  end

  # Mezzanine mode. Display and paginate each line separately.
  defp mezzanine_mode_content(
         top_predictions,
         bottom_predictions,
         current_time,
         bridge_status,
         bridge_enabled?,
         state
       ) do
    [selected_top_predictions, selected_bottom_predictions] =
      for predictions_list <- [top_predictions, bottom_predictions] do
        Enum.uniq_by(predictions_list, &route_key(&1))
      end

    messages =
      for prediction_list <- [selected_top_predictions, selected_bottom_predictions] do
        prediction_list
        |> Enum.map(&format_prediction(&1, nil, current_time))
        |> paginate_message()
      end

    audios =
      (selected_top_predictions ++ selected_bottom_predictions)
      |> Enum.map(&prediction_audio(&1, current_time))
      |> add_preamble()
      |> Stream.intersperse([:_])
      |> Stream.concat()
      |> paginate_audio()
      |> Enum.concat(bridge_audio(bridge_status, bridge_enabled?, current_time, state))

    {messages, audios}
  end

  defp special_harvard_content() do
    messages = [
      Content.Message.Custom.new("Board routes 71", :top),
      Content.Message.Custom.new("and 73 on upper level", :bottom)
    ]

    audios = paginate_audio([:board_routes_71_and_73_on_upper_level])
    {messages, audios}
  end

  # Update the sign if:
  # 1. it has never been updated before (we just booted up)
  # 2. the sign is about to auto-blank, so refresh it
  # 3. the content has changed, but wait until the existing content has paged at least once
  defp should_update?(messages, current_time, state) do
    %{last_update: last_update, current_messages: current_messages} = state

    !last_update ||
      Timex.after?(current_time, Timex.shift(last_update, seconds: 150)) ||
      (current_messages != messages &&
         Timex.after?(
           current_time,
           Timex.shift(last_update, seconds: Content.Utilities.content_duration(current_messages))
         ))
  end

  defp should_read?(current_time, state) do
    %{
      read_loop_interval: read_loop_interval,
      read_loop_offset: read_loop_offset,
      last_read_time: last_read_time
    } = state

    period = fn time -> div(Timex.to_unix(time) - read_loop_offset, read_loop_interval) end
    period.(current_time) != period.(last_read_time)
  end

  # SL waterfront stops are impacted by the Chelsea bridge, but don't display a persistent visual
  # message while it's up. To let people know about delays promptly, we read the drawbridge message
  # by itself if all of the following are true:
  # 1. the drawbridge just went up
  # 2. drawbridge messages are enabled
  # 3. we are at a stop that is impacted, but does not show visual drawbridge messages
  defp should_announce_drawbridge?(bridge_status, bridge_enabled?, current_time, state) do
    %{chelsea_bridge: chelsea_bridge, prev_bridge_status: prev_bridge_status} = state

    chelsea_bridge == "audio" && bridge_enabled? && prev_bridge_status &&
      bridge_status_raised?(bridge_status, current_time) &&
      !bridge_status_raised?(prev_bridge_status, current_time)
  end

  defp prediction_stale?(prediction, current_time) do
    Timex.before?(prediction.departure_time, Timex.shift(current_time, seconds: -5))
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

  # If the estimate is more than 30 mins ago, assume someone forgot to reset the status,
  # and treat the bridge as lowered.
  defp bridge_status_raised?(bridge_status, current_time) do
    bridge_status.raised? && bridge_status_minutes(bridge_status, current_time) > -30
  end

  defp bridge_message(bridge_status, bridge_enabled?, current_time, predictions, state) do
    %{chelsea_bridge: chelsea_bridge} = state

    if bridge_enabled? && chelsea_bridge == "audio_visual" &&
         bridge_status_raised?(bridge_status, current_time) do
      mins = bridge_status_minutes(bridge_status, current_time)

      line2 =
        case {mins > 0, predictions != []} do
          {true, true} -> "SL3 delays #{mins} more min"
          {true, false} -> "for #{mins} more minutes"
          {false, true} -> "Expect SL3 delays"
          {false, false} -> ""
        end

      [["Drawbridge is up", line2]]
    else
      []
    end
  end

  # Returns a list of audio messages describing the bridge status
  defp bridge_audio(bridge_status, bridge_enabled?, current_time, state) do
    %{chelsea_bridge: chelsea_bridge} = state

    if bridge_enabled? && chelsea_bridge &&
         bridge_status_raised?(bridge_status, current_time) do
      case bridge_status_minutes(bridge_status, current_time) do
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
  end

  defp route_key(prediction) do
    {PaEss.Utilities.prediction_route_name(prediction), prediction.headsign}
  end

  defp format_prediction(nil, _, _), do: ""

  # Returns a string representation of a prediction, suitable for displaying on a sign.
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

  defp add_preamble([]), do: []
  defp add_preamble(items), do: [[:upcoming_departures] | items]

  # Returns a list of audio tokens describing the given prediction.
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

  # Returns a list of audio tokens representing the special "long form" description of
  # the given prediction.
  defp long_prediction_audio(prediction, current_time, next_or_following) do
    preamble =
      case {PaEss.Utilities.prediction_route_name(prediction), next_or_following} do
        {nil, :next} -> [:the_next_bus_to]
        {nil, :following} -> [:the_following_bus_to]
        {str, :next} -> [:the_next, {:route, str}, :bus_to]
        {str, :following} -> [:the_following, {:route, str}, :bus_to]
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

  # Turns a list of audio tokens into a list of audio messages, chunking as needed to stay under
  # the max var limit.
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

  defp send_audio(audios, state) do
    %{pa_ess_loc: pa_ess_loc, audio_zones: audio_zones, sign_updater: sign_updater} = state

    if audios != [] && audio_zones != [] do
      sign_updater.send_audio({pa_ess_loc, audio_zones}, audios, 5, 180)
    end
  end
end
