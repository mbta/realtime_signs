defmodule Signs.Utilities.LastTrip do
  alias Content.Message
  alias Content.Message.LastTrip

  def get_last_trip_messages(
        messages,
        service_status,
        source
      ) do
    case service_status do
      {has_top_service_ended?, has_bottom_service_ended?} ->
        {unpacked_mz_top, unpacked_mz_bottom} = unpack_mezzanine_content(messages, source)
        {top_source, bottom_source} = source

        cond do
          # If combined alert status, only switch to Last Trip messaging once service has fully ended.
          # Note: This is a very rare or impossible case because trips wouldn't be running through a closed
          # stop so a last trip wouldn't be tracked. But we should account for it just in case.
          match?(%Message.Alert.NoService{}, unpacked_mz_top) ->
            if has_top_service_ended? and has_bottom_service_ended?,
              do:
                {%Content.Message.LastTrip.StationClosed{},
                 %Content.Message.LastTrip.ServiceEnded{}},
              else: messages

          has_top_service_ended? and has_bottom_service_ended? and
            not is_prediction?(unpacked_mz_top) and
              not is_prediction?(unpacked_mz_bottom) ->
            {%Content.Message.LastTrip.StationClosed{}, %Content.Message.LastTrip.ServiceEnded{}}

          has_top_service_ended? and not is_prediction?(unpacked_mz_top) ->
            if get_message_length(unpacked_mz_bottom) <= 18 do
              {unpacked_mz_bottom,
               %Content.Message.LastTrip.NoService{
                 destination: top_source.headway_destination,
                 page?: true
               }}
            else
              {%Content.Message.LastTrip.NoService{
                 destination: top_source.headway_destination,
                 page?: false
               }, unpacked_mz_bottom}
            end

          has_bottom_service_ended? and not is_prediction?(unpacked_mz_bottom) ->
            if get_message_length(unpacked_mz_top) <= 18 do
              {unpacked_mz_top,
               %Content.Message.LastTrip.NoService{
                 destination: bottom_source.headway_destination,
                 page?: true
               }}
            else
              {%Content.Message.LastTrip.NoService{
                 destination: bottom_source.headway_destination,
                 page?: false
               }, unpacked_mz_top}
            end

          true ->
            messages
        end

      has_service_ended? ->
        if has_service_ended?,
          do:
            {%LastTrip.PlatformClosed{destination: source.headway_destination},
             %LastTrip.ServiceEnded{}},
          else: messages
    end
  end

  defp unpack_mezzanine_content(messages, {top_source, bottom_source}) do
    case messages do
      # JFK/UMass case
      {%Message.GenericPaging{messages: [prediction, headway_top]},
       %Message.GenericPaging{messages: [_, headway_bottom]}} ->
        {%Message.Headways.Paging{
           destination: headway_top.destination,
           range: headway_bottom.range
         }, %{prediction | zone: "m"}}

      {%Message.Headways.Top{}, %Message.Headways.Bottom{range: range}} ->
        {%Message.Headways.Paging{destination: top_source.headway_destination, range: range},
         %Message.Headways.Paging{destination: bottom_source.headway_destination, range: range}}

      _ ->
        messages
    end
  end

  defp is_prediction?(message) do
    match?(%Content.Message.Predictions{}, message)
  end

  defp get_message_length(message) do
    message_string = Content.Message.to_string(message)

    if is_list(message_string) do
      Enum.max_by(message_string, fn {string, _} -> String.length(string) end)
      |> elem(0)
      |> String.length()
    else
      String.length(message_string)
    end
  end
end
