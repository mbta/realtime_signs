defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig
  @alert_headway_factor 1.4

  @spec get_messages(Signs.Realtime.t(), DateTime.t()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_messages(sign, current_time) do
    cond do
      config = single_source_config(sign) ->
        do_headway_messages(sign, config, current_time)

      config = config_by_headway_id(sign) ->
        do_headway_messages(sign, config, current_time)

      true ->
        {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end
  end

  @spec do_headway_messages(Signs.Realtime.t(), map(), DateTime.t()) ::
          {{map(), Content.Message.t()}, {map(), Content.Message.t()}}
  defp do_headway_messages(sign, config, current_time) do
    headway_range = sign.headway_engine.get_headways(config.stop_id)
    last_departure = sign.last_departure_engine.get_last_departure(config.stop_id)

    sign_stop_ids =
      sign.source_config
      |> Signs.Utilities.SourceConfig.sign_stop_ids()

    sign_routes =
      sign.source_config
      |> Signs.Utilities.SourceConfig.sign_routes()

    alert_status = sign.alerts_engine.max_stop_status(sign_stop_ids, sign_routes)

    case headway_range do
      :none ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {nil, nil} ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {:first_departure, range, first_departure} ->
        max_headway = Headway.ScheduleHeadway.max_headway(range)
        time_buffer = if max_headway, do: max_headway, else: 0

        if Headway.ScheduleHeadway.show_first_departure?(
             first_departure,
             Timex.now(),
             time_buffer
           ) do
          {
            {config,
             %Content.Message.Headways.Top{
               headsign: config.headway_direction_name,
               vehicle_type: vehicle_type(config.routes)
             }},
            {config, %Content.Message.Headways.Bottom{range: range}}
          }
        else
          {{config, Content.Message.Empty.new()}, {config, Content.Message.Empty.new()}}
        end

      {bottom, top} ->
        adjusted_range =
          if alert_status != :none do
            {
              if(bottom, do: (bottom * @alert_headway_factor) |> round()),
              if(top, do: (top * @alert_headway_factor) |> round)
            }
          else
            {bottom, top}
          end

        {{config,
          %Content.Message.Headways.Top{
            headsign: config.headway_direction_name,
            vehicle_type: vehicle_type(config.routes)
          }},
         {config,
          %Content.Message.Headways.Bottom{
            range: adjusted_range,
            last_departure: minutes_ago(last_departure, current_time)
          }}}
    end
  end

  defp vehicle_type(["743"]), do: :bus
  defp vehicle_type(_), do: :train

  @spec config_by_headway_id(Signs.Realtime.t()) :: SourceConfig.source() | nil
  defp config_by_headway_id(sign) do
    sign.source_config
    |> Tuple.to_list()
    |> List.flatten()
    |> Enum.find(& &1.source_for_headway?)
  end

  defp single_source_config(sign) do
    case sign.source_config do
      {[one]} -> one
      _ -> nil
    end
  end

  @spec minutes_ago(DateTime.t() | nil, DateTime.t()) :: integer() | nil
  defp minutes_ago(nil, _current_time) do
    nil
  end

  defp minutes_ago(departure_time, current_time) do
    diff =
      current_time
      |> DateTime.diff(departure_time)

    if diff < 5 do
      0
    else
      diff
      |> Kernel./(60)
      |> Float.ceil()
      |> Kernel.trunc()
    end
  end
end
