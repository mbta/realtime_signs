defmodule Signs.Bus do
  use GenServer
  require Logger

  @line_max 18
  @var_max 45
  @drawbridge_minutes "135"
  @drawbridge_soon "136"
  @drawbridge_minutes_spanish "152"
  @drawbridge_soon_spanish "157"
  @alert_levels [:station_closure, :suspension_closed_station]
  @sl_waterfront_route_ids MapSet.new(["741", "742", "743", "746"])

  @enforce_keys [
    :id,
    :pa_ess_loc,
    :scu_id,
    :text_zone,
    :audio_zones,
    :max_minutes,
    :configs,
    :top_configs,
    :bottom_configs,
    :extra_audio_configs,
    :chelsea_bridge,
    :read_loop_interval,
    :read_loop_offset,
    :config_engine,
    :prediction_engine,
    :bridge_engine,
    :alerts_engine,
    :routes_engine,
    :sign_updater,
    :prev_predictions,
    :prev_bridge_status,
    :current_messages,
    :last_update,
    :last_read_time,
    :pa_message_plays
  ]
  defstruct @enforce_keys ++ [default_mode: :off]

  @type t :: %__MODULE__{
          id: String.t(),
          pa_ess_loc: String.t(),
          scu_id: String.t(),
          text_zone: String.t(),
          audio_zones: [String.t()],
          max_minutes: integer(),
          default_mode: Engine.Config.sign_config(),
          configs: list(),
          top_configs: list(),
          bottom_configs: list(),
          extra_audio_configs: list(),
          chelsea_bridge: String.t() | nil,
          read_loop_interval: integer(),
          read_loop_offset: integer(),
          config_engine: module(),
          prediction_engine: module(),
          bridge_engine: module(),
          alerts_engine: module(),
          routes_engine: module(),
          sign_updater: module(),
          prev_predictions: list(),
          prev_bridge_status: nil | map(),
          current_messages: tuple(),
          last_update: nil | DateTime.t(),
          last_read_time: DateTime.t(),
          pa_message_plays: %{integer() => DateTime.t()}
        }

  def start_link(sign) do
    state = %__MODULE__{
      id: Map.fetch!(sign, "id"),
      pa_ess_loc: Map.fetch!(sign, "pa_ess_loc"),
      scu_id: Map.fetch!(sign, "scu_id"),
      text_zone: Map.fetch!(sign, "text_zone"),
      audio_zones: Map.fetch!(sign, "audio_zones"),
      max_minutes: Map.fetch!(sign, "max_minutes"),
      configs: parse_configs(sign["configs"]),
      top_configs: parse_configs(sign["top_configs"]),
      bottom_configs: parse_configs(sign["bottom_configs"]),
      extra_audio_configs: parse_configs(sign["extra_audio_configs"]),
      chelsea_bridge: sign["chelsea_bridge"],
      read_loop_interval: Map.fetch!(sign, "read_loop_interval"),
      read_loop_offset: Map.fetch!(sign, "read_loop_offset"),
      config_engine: Engine.Config,
      prediction_engine: Engine.BusPredictions,
      bridge_engine: Engine.ChelseaBridge,
      alerts_engine: Engine.Alerts,
      routes_engine: Engine.Routes,
      sign_updater: PaEss.Updater,
      prev_predictions: [],
      prev_bridge_status: nil,
      current_messages: {nil, nil},
      last_update: nil,
      last_read_time: Timex.now(),
      pa_message_plays: %{}
    }

    GenServer.start_link(__MODULE__, state, name: :"Signs/#{state.id}")
  end

  defp parse_configs(nil), do: nil

  defp parse_configs(configs) do
    for config <- configs do
      %{
        sources:
          for source <- Map.fetch!(config, "sources") do
            %{
              stop_id: Map.fetch!(source, "stop_id"),
              route_id: Map.fetch!(source, "route_id"),
              direction_id: Map.fetch!(source, "direction_id")
            }
          end
      }
    end
  end

  @impl true
  def init(state) do
    # This delay was chosen to be long enough to prevent individual sign crashes from restarting
    # the whole app, allowing some resilience against temporary external failures.
    Process.send_after(self(), :run_loop, 5000)
    {:ok, state}
  end

  @type content_values ::
          {messages :: [Content.Message.value()], audios :: [Content.Audio.value()],
           tts_audios :: [Content.Audio.tts_value()]}

  @impl true
  def handle_info({:play_pa_message, pa_message}, sign) do
    {:noreply, Signs.Utilities.Audio.handle_pa_message_play(pa_message, sign)}
  end

  @impl true
  def handle_info(:run_loop, state) do
    Process.send_after(self(), :run_loop, 1000)

    %__MODULE__{
      id: id,
      default_mode: default_mode,
      configs: configs,
      config_engine: config_engine,
      prediction_engine: prediction_engine,
      bridge_engine: bridge_engine,
      alerts_engine: alerts_engine,
      prev_predictions: prev_predictions
    } = state

    # Fetch the data we need to compute the updated sign content.
    config = config_engine.sign_config(id, default_mode)
    bridge_enabled? = config_engine.chelsea_bridge_config() == :auto
    bridge_status = bridge_engine.bridge_status()
    current_time = Timex.now()
    all_route_ids = all_route_ids(state)

    route_alerts_lookup =
      for route_id <- all_route_ids, into: %{} do
        {route_id, alerts_engine.route_status(route_id)}
      end

    stop_alerts_lookup =
      for stop_id <- all_stop_ids(state), into: %{} do
        {stop_id, alerts_engine.stop_status(stop_id)}
      end

    prev_predictions_lookup =
      for prediction <- prev_predictions,
          into: %{} do
        {prediction_key(prediction), prediction}
      end

    all_predictions = fetch_predictions(prev_predictions_lookup, current_time, state)

    predictions_lookup =
      all_predictions
      |> filter_predictions(current_time, state)
      |> Enum.group_by(&{&1.stop_id, &1.route_id, &1.direction_id})

    # Compute new sign text and audio
    {[top, bottom], audios, tts_audios} =
      cond do
        config_off?(config, all_route_ids) ->
          {_messages = ["", ""], _audios = [], _tts_audios = []}

        match?({:static_text, _}, config) ->
          static_text_content(
            config,
            bridge_status,
            bridge_enabled?,
            current_time,
            predictions_lookup,
            route_alerts_lookup,
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

        configs ->
          platform_mode_content(
            predictions_lookup,
            route_alerts_lookup,
            stop_alerts_lookup,
            current_time,
            bridge_status,
            bridge_enabled?,
            state
          )

        true ->
          mezzanine_mode_content(
            predictions_lookup,
            route_alerts_lookup,
            stop_alerts_lookup,
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
        state.sign_updater.set_background_message(state, top, bottom)
        %{state | current_messages: {top, bottom}, last_update: current_time}
      else
        state
      end
    end)
    |> then(fn state ->
      if should_read?(current_time, state) do
        send_audio(audios, tts_audios, state)
        %{state | last_read_time: current_time}
      else
        if should_announce_drawbridge?(bridge_status, bridge_enabled?, current_time, state) do
          bridge_audios = bridge_audio(bridge_status, bridge_enabled?, current_time, state)

          bridge_tts_audios =
            bridge_tts_audio(bridge_status, bridge_enabled?, current_time, state)

          send_audio(bridge_audios, bridge_tts_audios, state)
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

  defp fetch_predictions(prev_predictions_lookup, current_time, state) do
    %{prediction_engine: prediction_engine} = state

    for stop_id <- all_stop_ids(state),
        prediction <- prediction_engine.predictions_for_stop(stop_id),
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
  @spec static_text_content(
          Engine.Config.sign_config(),
          term(),
          boolean(),
          DateTime.t(),
          map(),
          map(),
          t()
        ) :: content_values()
  defp static_text_content(
         config,
         bridge_status,
         bridge_enabled?,
         current_time,
         predictions_lookup,
         route_alerts_lookup,
         state
       ) do
    {_, {line1, line2}} = config

    messages =
      [[line1, line2]]
      |> Enum.concat(
        bridge_message(
          bridge_status,
          bridge_enabled?,
          current_time,
          predictions_lookup,
          route_alerts_lookup,
          state
        )
      )
      |> paginate_pairs()

    audios =
      [{:ad_hoc, {"#{line1} #{line2}", :audio}}]
      |> Enum.concat(bridge_audio(bridge_status, bridge_enabled?, current_time, state))

    tts_audios = [{"#{line1} #{line2}", nil}]

    {messages, audios, tts_audios}
  end

  # Platform mode. Display one prediction per route, but if all the predictions are for the
  # same route, then show a single page of two.
  @spec platform_mode_content(map(), map(), map(), DateTime.t(), term(), boolean(), t()) ::
          content_values()
  defp platform_mode_content(
         predictions_lookup,
         route_alerts_lookup,
         stop_alerts_lookup,
         current_time,
         bridge_status,
         bridge_enabled?,
         state
       ) do
    %{configs: configs, extra_audio_configs: extra_audio_configs} = state
    content = configs_content(configs, predictions_lookup, route_alerts_lookup)
    # Special case: Nubian platform E has two separate text zones, but only one audio zone due
    # to close proximity. One sign process is configured to read out the other sign's prediction
    # list in addition to its own, while the other one stays silent.
    audio_content =
      content ++ configs_content(extra_audio_configs, predictions_lookup, route_alerts_lookup)

    if !Enum.any?(audio_content, &match?({:predictions, _}, &1)) &&
         all_stop_ids(state)
         |> Enum.all?(fn stop_id ->
           Map.get(stop_alerts_lookup, stop_id) in @alert_levels
         end) do
      no_service_content()
    else
      messages =
        case content do
          [single] ->
            format_long_message(single, current_time, state)

          list ->
            Stream.chunk_every(list, 2, 2, [nil])
            |> Stream.map(fn [first, second] ->
              [
                format_message(first, second, current_time, state),
                format_message(second, first, current_time, state)
              ]
            end)
        end
        |> Enum.concat(
          bridge_message(
            bridge_status,
            bridge_enabled?,
            current_time,
            predictions_lookup,
            route_alerts_lookup,
            state
          )
        )
        |> paginate_pairs()

      audios =
        case audio_content do
          [single] ->
            long_message_audio(single, current_time, state)

          list ->
            Enum.map(list, &message_audio(&1, current_time, state))
            |> add_preamble()
        end
        |> Stream.intersperse([:_])
        |> Stream.concat()
        |> paginate_audio()
        |> Enum.concat(bridge_audio(bridge_status, bridge_enabled?, current_time, state))

      tts_audios =
        case audio_content do
          [] ->
            []

          [single] ->
            [long_message_tts_audio(single, current_time, state)]

          list ->
            Enum.map(list, &message_tts_audio(&1, current_time, state))
            |> Enum.join(" ")
            |> add_tts_preamble()
            |> List.wrap()
        end
        |> Enum.map(&{&1, nil})
        |> Enum.concat(bridge_tts_audio(bridge_status, bridge_enabled?, current_time, state))

      {messages, audios, tts_audios}
    end
  end

  # Mezzanine mode. Display and paginate each line separately.
  @spec mezzanine_mode_content(map(), map(), map(), DateTime.t(), term(), boolean(), t()) ::
          content_values()
  defp mezzanine_mode_content(
         predictions_lookup,
         route_alerts_lookup,
         stop_alerts_lookup,
         current_time,
         bridge_status,
         bridge_enabled?,
         state
       ) do
    %{top_configs: top_configs, bottom_configs: bottom_configs} = state
    top_content = configs_content(top_configs, predictions_lookup, route_alerts_lookup)
    bottom_content = configs_content(bottom_configs, predictions_lookup, route_alerts_lookup)

    if !Enum.any?(top_content ++ bottom_content, &match?({:predictions, _}, &1)) &&
         all_stop_ids(state)
         |> Enum.all?(fn stop_id ->
           Map.get(stop_alerts_lookup, stop_id) in @alert_levels
         end) do
      no_service_content()
    else
      messages =
        for content <- [top_content, bottom_content] do
          Enum.map(content, &format_message(&1, nil, current_time, state))
          |> paginate_message()
        end

      audios =
        Enum.map(top_content ++ bottom_content, &message_audio(&1, current_time, state))
        |> add_preamble()
        |> Stream.intersperse([:_])
        |> Stream.concat()
        |> paginate_audio()
        |> Enum.concat(bridge_audio(bridge_status, bridge_enabled?, current_time, state))

      tts_audios =
        case top_content ++ bottom_content do
          [] ->
            []

          list ->
            Enum.map(list, &message_tts_audio(&1, current_time, state))
            |> Enum.join(" ")
            |> add_tts_preamble()
            |> List.wrap()
        end
        |> Enum.map(&{&1, nil})
        |> Enum.concat(bridge_tts_audio(bridge_status, bridge_enabled?, current_time, state))

      {messages, audios, tts_audios}
    end
  end

  @spec special_harvard_content() :: content_values()
  defp special_harvard_content() do
    messages = ["Board routes 71", "and 73 on upper level"]
    audios = paginate_audio([:board_routes_71_and_73_on_upper_level])
    tts_audios = [{"Board routes 71 and 73 on upper level", nil}]
    {messages, audios, tts_audios}
  end

  @spec no_service_content() :: content_values()
  defp no_service_content do
    messages = paginate_pairs([["No bus service", ""]])
    audios = paginate_audio([:no_bus_service])
    tts_audios = [{"No bus service", nil}]
    {messages, audios, tts_audios}
  end

  defp configs_content(nil, _, _), do: []

  defp configs_content(configs, predictions_lookup, route_alerts_lookup) do
    Enum.flat_map(configs, fn config ->
      content =
        Stream.flat_map(config.sources, fn source ->
          Map.get(predictions_lookup, {source.stop_id, source.route_id, source.direction_id}, [])
        end)
        |> Enum.group_by(&PaEss.Utilities.headsign_key(&1.headsign))
        |> Enum.map(fn {_, list} ->
          {:predictions, Enum.sort_by(list, & &1.departure_time, DateTime)}
        end)

      if content == [] &&
           Enum.all?(config.sources, fn source ->
             Map.get(route_alerts_lookup, source.route_id) in @alert_levels
           end) do
        [{:alert, config}]
      else
        content
      end
    end)
    |> Enum.sort_by(fn
      {:predictions, [first | _]} -> {0, DateTime.to_unix(first.departure_time)}
      {:alert, _} -> {1, nil}
    end)
  end

  defp all_sources(state) do
    %{
      configs: configs,
      top_configs: top_configs,
      bottom_configs: bottom_configs,
      extra_audio_configs: extra_audio_configs
    } = state

    for config_list <- [configs, top_configs, bottom_configs, extra_audio_configs],
        config_list,
        config <- config_list,
        source <- config.sources do
      source
    end
  end

  defp all_stop_ids(state) do
    for source <- all_sources(state), uniq: true, do: source.stop_id
  end

  defp all_route_ids(state) do
    for source <- all_sources(state), uniq: true, do: source.route_id
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
    Map.take(prediction, [:stop_id, :route_id, :vehicle_id, :direction_id, :trip_id])
  end

  defp bridge_status_minutes(bridge_status, current_time) do
    round(Timex.diff(bridge_status.estimate, current_time, :seconds) / 60)
  end

  # If the estimate is more than 30 mins ago, assume someone forgot to reset the status,
  # and treat the bridge as lowered.
  defp bridge_status_raised?(bridge_status, current_time) do
    bridge_status.raised? && bridge_status_minutes(bridge_status, current_time) > -30
  end

  defp bridge_message(
         bridge_status,
         bridge_enabled?,
         current_time,
         predictions_lookup,
         route_alerts_lookup,
         state
       ) do
    %{chelsea_bridge: chelsea_bridge, configs: configs} = state

    if bridge_enabled? && chelsea_bridge == "audio_visual" &&
         bridge_status_raised?(bridge_status, current_time) do
      mins = bridge_status_minutes(bridge_status, current_time)

      line2 =
        case {mins > 0, configs_content(configs, predictions_lookup, route_alerts_lookup) != []} do
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
        {:canned, {msg, vars, :audio_visual}}
      end)
    else
      []
    end
  end

  defp bridge_tts_audio(bridge_status, bridge_enabled?, current_time, state) do
    %{chelsea_bridge: chelsea_bridge} = state

    if bridge_enabled? && chelsea_bridge &&
         bridge_status_raised?(bridge_status, current_time) do
      {duration, duration_spanish} =
        case bridge_status_minutes(bridge_status, current_time) do
          minutes when minutes < 2 ->
            {"We expect it to be lowered soon.", "Esperamos que se baje pronto."}

          minutes ->
            {"We expect this to last for at least #{minutes} more minutes.",
             "Esperamos que esto dure al menos #{minutes} minutos más."}
        end

      english_text =
        "The Chelsea Street bridge is raised. #{duration} SL3 buses may be delayed, detoured, or turned back."

      spanish_text =
        "El puente de Chelsea Street está levantado. #{duration_spanish} Los autobuses SL3 pueden sufrir retrasos, desvíos o dar marcha atrás."

      [
        {english_text, PaEss.Utilities.paginate_text(english_text)},
        {spanish_text, PaEss.Utilities.paginate_text(spanish_text)}
      ]
    else
      []
    end
  end

  defp format_message(nil, _, _, _state), do: ""

  defp format_message({:predictions, [first | _]}, other, current_time, _state) do
    other_prediction =
      case other do
        {:predictions, [other_first | _]} -> other_first
        _ -> nil
      end

    format_prediction(first, other_prediction, current_time)
  end

  defp format_message({:alert, config}, _, _, state) do
    %{route_id: route_id, direction_id: direction_id} = config.sources |> List.first()

    route =
      if length(config.sources) > 1 || route_id in ["741", "742", "743", "746"],
        do: "",
        else: route_id <> " "

    no_svc = "no svc"

    dest =
      headsign_abbreviation(
        state.routes_engine.route_destination(route_id, direction_id),
        @line_max - String.length(route) - String.length(no_svc) - 1
      )

    Content.Utilities.width_padded_string("#{route}#{dest}", no_svc, @line_max)
  end

  defp format_long_message({:predictions, [single]}, current_time, _state) do
    [[format_prediction(single, nil, current_time), ""]]
  end

  defp format_long_message({:predictions, [first, second | _]}, current_time, _state) do
    [
      [
        format_prediction(first, second, current_time),
        format_prediction(second, first, current_time)
      ]
    ]
  end

  defp format_long_message({:alert, _} = message, current_time, state) do
    [[format_message(message, nil, current_time, state), ""]]
  end

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

    # Choose the longest abbreviation that will fit within the remaining space.
    dest =
      headsign_abbreviation(headsign, @line_max - String.length(route) - String.length(time) - 1)

    Content.Utilities.width_padded_string("#{route}#{dest}", time, @line_max)
  end

  defp config_route_name(%{sources: [first | _] = sources}) do
    if length(sources) > 1 || first.route_id in ["741", "742", "743", "746"],
      do: nil,
      else: first.route_id
  end

  defp config_headsign(%{sources: [first | _]}, state) do
    state.routes_engine.route_destination(first.route_id, first.direction_id)
  end

  defp headsign_abbreviation(headsign, max_size) do
    [headsign | PaEss.Utilities.headsign_abbreviations(headsign)]
    |> Enum.filter(&(String.length(&1) <= max_size))
    |> Enum.max_by(&String.length/1, fn ->
      Logger.warn("No abbreviation for headsign: #{inspect(headsign)}")
      headsign
    end)
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
    case pages do
      [] -> ""
      [s] -> s
      _ -> for s <- pages, do: {s, 6}
    end
  end

  defp paginate_pairs(pairs) do
    [
      paginate_message(for [x, _] <- pairs, do: x),
      paginate_message(for [_, x] <- pairs, do: x)
    ]
  end

  defp add_preamble([]), do: []
  defp add_preamble(items), do: [[:upcoming_departures] | items]

  defp add_tts_preamble(str), do: "Upcoming departures: " <> str

  # Returns a list of audio tokens describing the given message.
  defp message_audio({:predictions, [prediction | _]}, current_time, _state) do
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

  defp message_audio({:alert, config}, _, state) do
    route =
      case config_route_name(config) do
        nil -> []
        str -> [{:route, str}]
      end

    headsign = config_headsign(config, state)

    route ++ [{:headsign, headsign}, :no_service]
  end

  defp message_tts_audio({:predictions, [prediction | _]}, current_time, _state) do
    route =
      case PaEss.Utilities.prediction_route_name(prediction) do
        nil -> ""
        name -> "Route #{name}, "
      end

    time =
      case prediction_minutes(prediction, current_time) do
        0 -> "arriving"
        1 -> "1 minute"
        m -> "#{m} minutes"
      end

    "#{route}#{prediction.headsign}, #{time}."
  end

  defp message_tts_audio({:alert, config}, _, state) do
    route =
      case config_route_name(config) do
        nil -> ""
        name -> "Route #{name}, "
      end

    headsign = config_headsign(config, state)
    "#{route}#{headsign}, no service."
  end

  # Returns a list of audio tokens representing the special "long form" description of
  # the given prediction.
  defp long_message_audio({:predictions, predictions}, current_time, _state) do
    Stream.take(predictions, 2)
    |> Enum.zip_with([:next, :following], fn prediction, next_or_following ->
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
    end)
  end

  defp long_message_audio({:alert, config}, _, state) do
    route =
      case config_route_name(config) do
        nil -> []
        str -> [{:route, str}]
      end

    headsign = config_headsign(config, state)

    [Enum.concat([[:there_is_no], route, [:bus_service_to, {:headsign, headsign}]])]
  end

  defp long_message_tts_audio({:predictions, predictions}, current_time, _state) do
    Stream.take(predictions, 2)
    |> Enum.zip_with(["next", "following"], fn prediction, next_or_following ->
      route =
        case PaEss.Utilities.prediction_route_name(prediction) do
          nil -> ""
          name -> "route #{name} "
        end

      time =
        case prediction_minutes(prediction, current_time) do
          0 -> "is now arriving"
          1 -> "arrives in 1 minute"
          m -> "arrives in #{m} minutes"
        end

      "The #{next_or_following} #{route}bus to #{prediction.headsign} #{time}."
    end)
    |> Enum.join(" ")
  end

  defp long_message_tts_audio({:alert, config}, _, state) do
    route =
      case config_route_name(config) do
        nil -> ""
        name -> "route #{name} "
      end

    headsign = config_headsign(config, state)
    "There is no #{route}bus service to #{headsign}."
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
      {:canned, {PaEss.Utilities.take_message_id(vars), vars, :audio}}
    end)
  end

  defp send_audio(audios, tts_audios, state) do
    %{audio_zones: audio_zones, sign_updater: sign_updater} = state

    if audios != [] && audio_zones != [] do
      sign_updater.play_message(
        state,
        audios,
        tts_audios,
        Enum.map(audios, fn _ -> [message_type: "Bus"] end)
      )
    end
  end

  # If a Silver Line sign is in headway mode, SignsUI will flag its predictions but RTS needs to treat it as off
  defp config_off?(:headway, route_ids),
    do: route_ids |> MapSet.new() |> MapSet.subset?(@sl_waterfront_route_ids)

  defp config_off?(:off, _), do: true
  defp config_off?(_, _), do: false
end
