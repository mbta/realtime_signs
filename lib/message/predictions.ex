defmodule Message.Predictions do
  @enforce_keys [
    :predictions,
    :terminal?,
    :announce_arriving?,
    :announce_boarding?,
    :special_sign
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          predictions: [Predictions.Prediction.t()],
          terminal?: boolean(),
          announce_arriving?: boolean(),
          announce_boarding?: boolean(),
          # For JFK platform, track if Alewife-bound trains are using a single platform,
          # indicated by `true`.
          special_sign: {:jfk_mezzanine, true | false} | :bowdoin_eastbound | nil
        }

  defimpl Message do
    def to_single_line(
          %Message.Predictions{
            predictions: [first | _],
            terminal?: terminal?,
            special_sign: special_sign
          },
          line_size
        ) do
      destination = Content.Utilities.destination_for_prediction(first)
      headsign = PaEss.Utilities.destination_to_sign_string(destination, first.route_id)

      stopped? = PaEss.Utilities.prediction_stopped?(first, terminal?)
      jfk_nb? = match?({:jfk_mezzanine, _}, special_sign) and first.direction_id == 1

      cond do
        stopped? and line_size == :short ->
          nil

        stopped? and line_size == :long ->
          Content.Utilities.width_padded_string(headsign, stops_away(first), 24)

        jfk_nb? and line_size == :short ->
          nil

        jfk_nb? and line_size == :long ->
          duration = duration(first, terminal?)

          {headsign_message, platform_message} =
            case platform(first, terminal?, special_sign) do
              :tbd -> {headsign, " (Platform TBD)"}
              platform -> {"#{headsign} (#{String.slice(platform, 0..0)})", " (#{platform} plat)"}
            end

          [
            {Content.Utilities.width_padded_string(headsign_message, duration, 18), 6},
            {headsign <> platform_message, 6}
          ]

        true ->
          prediction_message(first, terminal?)
      end
    end

    def to_full_page(%Message.Predictions{
          predictions: [first | rest],
          terminal?: terminal?,
          special_sign: special_sign
        }) do
      if PaEss.Utilities.prediction_stopped?(first, terminal?) do
        destination = Content.Utilities.destination_for_prediction(first)
        headsign = PaEss.Utilities.destination_to_sign_string(destination, first.route_id)
        {headsign, "Stopped #{stops_away(first)}"}
      else
        track = Content.Utilities.stop_track_number(first.stop_id)
        platform = platform(first, terminal?, special_sign)
        four_cars? = four_cars?(first, terminal?)

        second_line =
          cond do
            is_integer(track) -> "On track #{track}"
            platform == :tbd -> "platform TBD"
            is_binary(platform) -> "on #{platform} platform"
            four_cars? -> Content.Utilities.width_padded_string("4 cars", "Move to front", 24)
            rest != [] -> prediction_message(hd(rest), terminal?)
            true -> ""
          end

        {prediction_message(first, terminal?), second_line}
      end
    end

    def to_audio(
          %Message.Predictions{
            predictions: [first | _] = predictions,
            terminal?: terminal?,
            special_sign: special_sign
          },
          multiple?
        ) do
      same_destination? =
        Enum.map(predictions, &Content.Utilities.destination_for_prediction(&1))
        |> Enum.uniq()
        |> length() == 1

      four_cars? = four_cars?(first, terminal?)
      track = Content.Utilities.stop_track_number(first.stop_id)

      Enum.take(predictions, if(multiple? or four_cars? or !!track, do: 1, else: 2))
      |> Enum.zip(if(same_destination?, do: [:next, :following], else: [:next, :next]))
      |> Enum.with_index()
      |> Enum.map(fn {{prediction, next_or_following}, index} ->
        %Content.Audio.Predictions{
          prediction: prediction,
          special_sign: special_sign,
          terminal?: terminal?,
          multiple_messages?: multiple?,
          next_or_following: next_or_following,
          is_first?: index == 0
        }
      end)
    end

    defp prediction_message(prediction, terminal?) do
      destination = Content.Utilities.destination_for_prediction(prediction)
      headsign = PaEss.Utilities.destination_to_sign_string(destination, prediction.route_id)
      duration = duration(prediction, terminal?)
      Content.Utilities.width_padded_string(headsign, duration, 18)
    end

    defp stops_away(prediction) do
      num = PaEss.Utilities.prediction_stops_away(prediction)
      stops = if(num == 1, do: "stop", else: "stops")
      "#{num} #{stops} away"
    end

    defp duration(prediction, terminal?) do
      {minutes, approximate?} = PaEss.Utilities.prediction_minutes(prediction, terminal?)

      case minutes do
        :boarding -> "BRD"
        :arriving -> "ARR"
        n -> "#{n}#{if approximate?, do: "+", else: ""} min"
      end
    end

    # At the JFK mezzanine, only show the platform if the train is within 5 minutes of arriving,
    # unless all predictions are for the same platform (meaning the other branch is not running)
    defp platform(prediction, terminal?, {:jfk_mezzanine, all_same_stop_id?}) do
      {minutes, _} = PaEss.Utilities.prediction_minutes(prediction, terminal?)

      if is_integer(minutes) and minutes > 5 and not all_same_stop_id? do
        :tbd
      else
        Content.Utilities.stop_platform_name(prediction.stop_id)
      end
    end

    defp platform(_prediction, _terminal?, _), do: nil

    defp four_cars?(prediction, terminal?) do
      PaEss.Utilities.prediction_four_cars?(prediction) and
        (not terminal? or PaEss.Utilities.prediction_ashmont?(prediction))
    end
  end
end
