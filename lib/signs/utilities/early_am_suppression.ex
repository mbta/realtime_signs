defmodule Signs.Utilities.EarlyAmSuppression do
  alias Content.Message
  alias Content.Message.Headways
  alias Content.Message.EarlyAm

  def do_early_am_suppression(
        messages,
        current_time,
        early_am_status,
        schedule,
        sign
      ) do
    case early_am_status do
      {_, _} ->
        {top_content, bottom_content} =
          get_mezzanine_early_am_content(
            messages,
            sign,
            align_schedules(schedule, messages),
            early_am_status,
            current_time
          )

        cond do
          match?(
            {%Message.Predictions{station_code: "RJFK", zone: "m"}, _},
            bottom_content
          ) ->
            cond do
              match?({%EarlyAm.DestinationTrain{}, _}, top_content) or
                  match?({%Headways.Top{}, _}, top_content) ->
                {bottom, _} = bottom_content

                # Set zone to nil to prevent usual paging behavior for RJFK Mezzanine
                paginate(
                  top_content,
                  {%{bottom | zone: nil},
                   %Message.PlatformPredictionBottom{
                     stop_id: bottom.stop_id,
                     minutes: bottom.minutes
                   }}
                )

              true ->
                {top, _} = top_content
                {bottom, _} = bottom_content
                {top, bottom}
            end

          match?({%Message.Predictions{}, _}, top_content) or
              match?({%Message.StoppedTrain{}, _}, top_content) ->
            {top, _} = top_content
            {top, map_to_single_line_content(bottom_content)}

          match?({%Message.Predictions{}, _}, bottom_content) or
              match?({%Message.StoppedTrain{}, _}, bottom_content) ->
            {bottom, _} = bottom_content

            case map_to_single_line_content(top_content) do
              %EarlyAm.DestinationScheduledTime{} = top ->
                {bottom, top}

              %Headways.Paging{} = top ->
                {bottom, top}

              top ->
                {top, bottom}
            end

          match?({%Message.GenericPaging{}, _}, top_content) and
              match?({%Message.GenericPaging{}, _}, bottom_content) ->
            {top, _} = top_content
            {bottom, _} = bottom_content
            {top, bottom}

          match?({{%Headways.Top{}, _}, {%Headways.Top{}, _}}, {top_content, bottom_content}) ->
            top_content

          true ->
            paginate(top_content, bottom_content)
        end

      status ->
        get_source_early_am_content(
          sign,
          sign.source_config,
          messages,
          align_schedules(schedule, messages),
          status,
          current_time
        )
    end
  end

  # Swaps the top and bottom first scheduled departures when the destinations don't match up.
  # This is possible when the top line wants to page headways and the messages get switched.
  defp align_schedules(scheduled, messages) do
    case scheduled do
      {{top_scheduled, top_dest}, {bottom_scheduled, bottom_dest}} ->
        case messages do
          {%Message.Empty{}, _} ->
            scheduled

          {%Message.GenericPaging{messages: [m1 | _]}, _} ->
            if m1.destination == top_dest do
              scheduled
            else
              {{bottom_scheduled, bottom_dest}, {top_scheduled, top_dest}}
            end

          {m1, _} ->
            if m1.destination == top_dest do
              scheduled
            else
              {{bottom_scheduled, bottom_dest}, {top_scheduled, top_dest}}
            end
        end

      _ ->
        scheduled
    end
  end

  defp get_mezzanine_early_am_content(
         messages,
         sign,
         schedule,
         statuses,
         current_time
       ) do
    {top_scheduled, bottom_scheduled} = schedule
    {top_message, bottom_message} = messages
    {top_source, bottom_source} = sign.source_config
    {top_status, bottom_status} = statuses

    top_content =
      if top_status == :none,
        do: {top_message, %Message.Empty{}},
        else:
          get_source_early_am_content(
            sign,
            top_source,
            {top_message, %Message.Empty{}},
            top_scheduled,
            top_status,
            current_time
          )

    bottom_content =
      if bottom_status == :none,
        do: {bottom_message, %Message.Empty{}},
        else:
          get_source_early_am_content(
            sign,
            bottom_source,
            {bottom_message, %Message.Empty{}},
            bottom_scheduled,
            bottom_status,
            current_time
          )

    {top_content, bottom_content}
  end

  defp get_source_early_am_content(
         sign,
         source,
         messages,
         {scheduled, destination},
         status,
         current_time
       ) do
    cond do
      status == :fully_suppressed ->
        {%EarlyAm.DestinationTrain{destination: source.headway_destination},
         %EarlyAm.ScheduledTime{
           scheduled_time: scheduled
         }}

      status == :partially_suppressed ->
        case filter_early_am_messages(messages, sign.id) do
          {%Message.Empty{}, %Message.Empty{}} ->
            # If no valid predictions, try fetching headways
            case Signs.Utilities.Headways.get_messages(sign, current_time) do
              # If no headways are returned, default to timestamp message
              {%Message.Empty{}, %Message.Empty{}} ->
                {%EarlyAm.DestinationTrain{
                   destination: destination
                 },
                 %EarlyAm.ScheduledTime{
                   scheduled_time: scheduled
                 }}

              {headway_top, headway_bottom} ->
                {%{headway_top | destination: destination}, headway_bottom}
            end

          messages ->
            messages
        end
    end
  end

  defp filter_early_am_messages(messages, sign_id) do
    Tuple.to_list(messages)
    |> Enum.map(fn
      message ->
        cond do
          match?(%Message.Predictions{}, message) and message.certainty > 120 and
              sign_id not in ["symphony_eastbound", "prudential_eastbound"] ->
            Message.Empty.new()

          match?(%Headways.Top{}, message) or
              match?(%Headways.Bottom{}, message) ->
            Message.Empty.new()

          true ->
            message
        end
    end)
    |> then(fn
      [%Message.Empty{}, _] = messages ->
        Enum.reverse(messages)

      messages ->
        messages
    end)
    |> List.to_tuple()
  end

  defp map_to_single_line_content(message) do
    case message do
      {%EarlyAm.DestinationTrain{} = m1, m2} ->
        %EarlyAm.DestinationScheduledTime{
          destination: m1.destination,
          scheduled_time: m2.scheduled_time
        }

      {%Headways.Top{} = m1, m2} ->
        %Headways.Paging{destination: m1.destination, range: m2.range}

      {m1, _} ->
        m1
    end
  end

  defp paginate(top_content, bottom_content) do
    [top, bottom] = Enum.zip(Tuple.to_list(top_content), Tuple.to_list(bottom_content))

    {%Message.GenericPaging{
       messages: Tuple.to_list(top)
     },
     %Message.GenericPaging{
       messages: Tuple.to_list(bottom)
     }}
  end

  @doc "Filters predictions based on certainty during early AM hours with the exception of Symphony and Prudential EB"

  def get_early_am_state(
        current_time,
        {{_, _} = top_first_scheduled, {_, _} = bottom_first_scheduled}
      ) do
    {
      get_early_am_state(current_time, top_first_scheduled),
      get_early_am_state(current_time, bottom_first_scheduled)
    }
  end

  def get_early_am_state(current_time, {first_scheduled_departure, _dest}) do
    cond do
      full_early_am_suppression?(current_time, first_scheduled_departure) ->
        :fully_suppressed

      partial_early_am_suppression?(current_time, first_scheduled_departure) ->
        :partially_suppressed

      true ->
        :none
    end
  end

  defp full_early_am_suppression?(current_time, first_scheduled_departure) do
    after_am_suppression_start?(current_time) and
      before_am_suppression_end?(current_time, first_scheduled_departure)
  end

  defp partial_early_am_suppression?(current_time, first_scheduled_departure) do
    not before_am_suppression_end?(current_time, first_scheduled_departure) and
      before_scheduled_start?(current_time, first_scheduled_departure)
  end

  defp after_am_suppression_start?(current_time) do
    Time.compare(DateTime.to_time(current_time), ~T[03:29:00]) == :gt
  end

  defp before_am_suppression_end?(current_time, first_scheduled_departure)
       when not is_nil(first_scheduled_departure) do
    DateTime.compare(
      current_time,
      first_scheduled_departure |> Timex.shift(minutes: -40)
    ) == :lt
  end

  defp before_am_suppression_end?(_, _), do: false

  defp before_scheduled_start?(current_time, first_scheduled_departure)
       when not is_nil(first_scheduled_departure) do
    DateTime.compare(current_time, first_scheduled_departure) == :lt
  end

  defp before_scheduled_start?(_, _), do: false
end
