defmodule Message.Predictions do
  @enforce_keys [:predictions, :terminal?, :special_sign]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          predictions: [Predictions.Prediction.t()],
          terminal?: boolean(),
          special_sign: :jfk_mezzanine | :jfk_mezzanine_single_platform | :bowdoin_eastbound | nil
        }

  defimpl Message do
    @width 18

    def to_single_line(%Message.Predictions{predictions: [top | _]} = message, :long) do
      prediction_message(top, message.terminal?, message.special_sign)
    end

    def to_single_line(%Message.Predictions{}, :short), do: nil

    def to_full_page(
          %Message.Predictions{predictions: [top | _], special_sign: :jfk_mezzanine} = message
        ) do
      {minutes, _} = PaEss.Utilities.prediction_minutes(top, message.terminal?)
      platform_name = Content.Utilities.stop_platform_name(top.stop_id)

      {prediction_message(top, message.terminal?, nil),
       if(is_integer(minutes) and minutes > 5,
         do: "platform TBD",
         else: "on #{platform_name} platform"
       )}
    end

    # Show 4-car messages at non-terminal Red Line stops with the exception of Ashmont
    def to_multi_line(
          %Message.Predictions{
            predictions: [%{route_id: "Red", multi_carriage_details: [_, _, _, _]} = top | _]
          } = message
        )
        when top.stop_id == "70094" or not message.terminal? do
      {prediction_message(top, message.terminal?, nil),
       Content.Utilities.width_padded_string("4 cars", "Move to front", 24)}
    end

    def to_multi_line(%Message.Predictions{predictions: [top]} = message) do
      {prediction_message(top, message.terminal?, message.special_sign), ""}
    end

    def to_multi_line(%Message.Predictions{predictions: [top, bottom]} = message) do
      {prediction_message(top, message.terminal?, message.special_sign),
       prediction_message(bottom, message.terminal?, message.special_sign)}
    end

    def to_audio(%Message.Predictions{} = message, multiple?) do
      same_destination? =
        Enum.map(message.predictions, &Content.Utilities.destination_for_prediction(&1))
        |> Enum.uniq()
        |> length() == 1

      four_cars? =
        hd(message.predictions) |> PaEss.Utilities.prediction_four_cars?() and !multiple? and
          (!message.terminal? or hd(message.predictions) |> PaEss.Utilities.prediction_ashmont?())

      Enum.take(message.predictions, if(multiple? or four_cars?, do: 1, else: 2))
      |> Enum.zip(if(same_destination?, do: [:next, :following], else: [:next, :next]))
      |> Enum.with_index()
      |> Enum.map(fn {{prediction, next_or_following}, index} ->
        %Content.Audio.Predictions{
          prediction: prediction,
          special_sign: message.special_sign,
          terminal?: message.terminal?,
          multiple_messages?: multiple?,
          next_or_following: next_or_following,
          is_first?: index == 0
        }
      end)
    end

    defp prediction_message(prediction, terminal?, special_sign) do
      destination = Content.Utilities.destination_for_prediction(prediction)
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      if PaEss.Utilities.prediction_stopped?(prediction, terminal?) do
        num = PaEss.Utilities.prediction_stops_away(prediction)
        stops = if(num == 1, do: "stop", else: "stops")

        [
          {Content.Utilities.width_padded_string(headsign, "Stopped", @width), 6},
          {Content.Utilities.width_padded_string(headsign, "#{num} #{stops}", @width), 6},
          {Content.Utilities.width_padded_string(headsign, "away", @width), 6}
        ]
      else
        {minutes, approximate?} = PaEss.Utilities.prediction_minutes(prediction, terminal?)

        duration =
          case minutes do
            :boarding -> "BRD"
            :arriving -> "ARR"
            n -> "#{n}#{if approximate?, do: "+", else: ""} min"
          end

        track_number = Content.Utilities.stop_track_number(prediction.stop_id)

        cond do
          special_sign in [:jfk_mezzanine, :jfk_mezzanine_single_platform] and
              destination == :alewife ->
            platform_name = Content.Utilities.stop_platform_name(prediction.stop_id)

            {headsign_message, platform_message} =
              if is_integer(minutes) and minutes > 5 and special_sign == :jfk_mezzanine do
                {headsign, " (Platform TBD)"}
              else
                {"#{headsign} (#{String.slice(platform_name, 0..0)})", " (#{platform_name} plat)"}
              end

            [
              {Content.Utilities.width_padded_string(headsign_message, duration, @width), 6},
              {headsign <> platform_message, 6}
            ]

          track_number ->
            [
              {Content.Utilities.width_padded_string(headsign, duration, @width), 6},
              {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", @width), 6}
            ]

          true ->
            Content.Utilities.width_padded_string(headsign, duration, @width)
        end
      end
    end
  end
end
