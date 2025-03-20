defmodule Content.Audio.Predictions do
  @enforce_keys [
    :prediction,
    :special_sign,
    :terminal?,
    :multiple_messages?,
    :next_or_following,
    :is_first?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          prediction: Predictions.Prediction.t(),
          special_sign: :jfk_mezzanine | :bowdoin_eastbound | nil,
          terminal?: boolean(),
          multiple_messages?: boolean(),
          next_or_following: :next | :following,
          is_first?: boolean()
        }

  @spec new(
          Predictions.Prediction.t(),
          :jfk_mezzanine | :bowdoin_eastbound | nil,
          boolean(),
          boolean(),
          :next | :following,
          boolean()
        ) :: [t()]
  def new(
        %Predictions.Prediction{} = prediction,
        special_sign,
        terminal?,
        multiple_messages?,
        next_or_following,
        is_first?
      ) do
    [
      %__MODULE__{
        prediction: prediction,
        special_sign: special_sign,
        terminal?: terminal?,
        multiple_messages?: multiple_messages?,
        next_or_following: next_or_following,
        is_first?: is_first?
      }
    ]
  end

  defimpl Content.Audio do
    @announce_platform_later_mins 9
    @announce_platform_soon_mins 5

    def to_params(%Content.Audio.Predictions{prediction: prediction} = audio) do
      destination = Content.Utilities.destination_for_prediction(prediction)

      the_next_or_following =
        if(audio.next_or_following == :next, do: :the_next, else: :the_following)

      train = PaEss.Utilities.train_description_tokens(destination, prediction.route_id)

      if PaEss.Utilities.prediction_stopped?(prediction, audio.terminal?) do
        num_stops_away = PaEss.Utilities.prediction_stops_away(prediction)
        stop_or_stops_away = if(num_stops_away == 1, do: :stop_away, else: :stops_away)

        [the_next_or_following] ++
          train ++ [:is, :stopped, {:number, num_stops_away}, stop_or_stops_away]
      else
        track_number = Content.Utilities.stop_track_number(prediction.stop_id)
        {platform, platform_prefix?, platform_tbd} = platform_status(audio)
        {minutes, _} = PaEss.Utilities.prediction_minutes(prediction, audio.terminal?)
        min_or_mins = if(minutes == 1, do: :minute, else: :minutes)

        status =
          cond do
            minutes == :arriving -> [:is_now_arriving]
            minutes == :boarding -> [:is_now_boarding]
            audio.terminal? -> [:departs, :in, {:number, minutes}, min_or_mins]
            true -> [:arrives, :in, {:number, minutes}, min_or_mins]
          end

        qualifier =
          cond do
            track_number == 1 -> [:on_track_1]
            track_number == 2 -> [:on_track_2]
            platform -> [:on_the, platform, :platform]
            true -> []
          end

        followup =
          case platform_tbd do
            :later -> [:will_announce_platform_later]
            :soon -> [:will_announce_platform_soon]
            _ -> []
          end

        {prefix, suffix} = if(platform_prefix?, do: {qualifier, []}, else: {[], qualifier})
        four_cars = if four_cars?(audio), do: [:four_car_train_message], else: []

        [the_next_or_following] ++ train ++ prefix ++ status ++ suffix ++ followup ++ four_cars
      end
      |> PaEss.Utilities.audio_message()
    end

    def to_tts(%Content.Audio.Predictions{prediction: prediction} = audio) do
      destination = Content.Utilities.destination_for_prediction(prediction)
      next_or_following = if(audio.next_or_following == :next, do: "next", else: "following")
      train = PaEss.Utilities.train_description(destination, prediction.route_id)

      text =
        if PaEss.Utilities.prediction_stopped?(prediction, audio.terminal?) do
          num_stops_away = PaEss.Utilities.prediction_stops_away(prediction)
          stop_or_stops = if(num_stops_away == 1, do: "stop", else: "stops")
          "The #{next_or_following} #{train} is stopped #{num_stops_away} #{stop_or_stops} away."
        else
          track_number = Content.Utilities.stop_track_number(prediction.stop_id)
          {platform, platform_prefix?, platform_tbd} = platform_status(audio)
          {minutes, _} = PaEss.Utilities.prediction_minutes(prediction, audio.terminal?)
          min_or_mins = if(minutes == 1, do: "minute", else: "minutes")

          status =
            cond do
              minutes == :arriving -> "is now arriving"
              minutes == :boarding -> "is now boarding"
              audio.terminal? -> "departs in #{minutes} #{min_or_mins}"
              true -> "arrives in #{minutes} #{min_or_mins}"
            end

          qualifier =
            cond do
              track_number -> " on track #{track_number}"
              platform -> " on the #{platform_string(platform)} platform"
              true -> ""
            end

          {prefix, suffix} = if(platform_prefix?, do: {qualifier, ""}, else: {"", qualifier})

          followup =
            case platform_tbd do
              :later -> " We will announce the platform for boarding when the train is closer."
              :soon -> " We will announce the platform for boarding soon."
              _ -> ""
            end

          four_cars = if four_cars?(audio), do: PaEss.Utilities.four_cars_text(), else: ""

          "The #{next_or_following} #{train}#{prefix} #{status}#{suffix}.#{followup}#{four_cars}"
        end

      {text, nil}
    end

    def to_logs(%Content.Audio.Predictions{}) do
      []
    end

    @spec platform_status(Content.Audio.t()) ::
            {platform :: Content.platform() | nil, platform_prefix? :: boolean(),
             platform_tbd :: :later | :soon | nil}
    defp platform_status(audio) do
      {minutes, _} = PaEss.Utilities.prediction_minutes(audio.prediction, audio.terminal?)
      platform = Content.Utilities.stop_platform(audio.prediction.stop_id)
      jfk_mezzanine? = audio.special_sign == :jfk_mezzanine

      cond do
        !platform -> {nil, false, nil}
        jfk_mezzanine? and minutes > @announce_platform_later_mins -> {nil, false, :later}
        jfk_mezzanine? and minutes > @announce_platform_soon_mins -> {nil, false, :soon}
        minutes == 1 or !jfk_mezzanine? -> {platform, true, nil}
        true -> {platform, false, nil}
      end
    end

    defp four_cars?(audio) do
      PaEss.Utilities.prediction_four_cars?(audio.prediction) and
        (!audio.terminal? or audio.prediction.stop_id === "70094") and
        !audio.multiple_messages? and audio.next_or_following == :next and
        audio.is_first?
    end

    defp platform_string(:ashmont), do: "Ashmont"
    defp platform_string(:braintree), do: "Braintree"
  end
end
