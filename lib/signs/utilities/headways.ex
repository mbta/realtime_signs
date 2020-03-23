defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig

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

  @spec get_configured_messages(Signs.Realtime.t(), Engine.Config.Headway.t()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_configured_messages(sign, %Engine.Config.Headway{
        range_low: low,
        range_high: high,
        non_platform_text_line1: line1,
        non_platform_text_line2: line2
      }) do
    case single_source_config(sign) do
      nil ->
        if line1 || line2 do
          {{nil, Content.Message.Custom.new(line1 || "", :top)},
           {nil, Content.Message.Custom.new(line2 || "", :bottom)}}
        else
          {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
        end

      # Mezzanine / Center platform, blank for now

      %SourceConfig{} = config ->
        {
          {config,
           %Content.Message.Headways.Top{
             destination: config.headway_destination,
             vehicle_type: vehicle_type(config.routes)
           }},
          {config, %Content.Message.Headways.Bottom{range: {low, high}, prev_departure_mins: nil}}
        }
    end
  end

  @spec do_headway_messages(Signs.Realtime.t(), map(), DateTime.t()) ::
          {{map(), Content.Message.t()}, {map(), Content.Message.t()}}
  defp do_headway_messages(sign, config, current_time) do
    stop_id = sign.headway_stop_id || config.stop_id
    headway_range = sign.headway_engine.get_headways(stop_id)
    _last_departure = sign.last_departure_engine.get_last_departure(config.stop_id)

    case headway_range do
      :none ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {nil, nil} ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {:first_departure, range, first_departure} ->
        max_headway = Headway.HeadwayDisplay.max_headway(range)
        time_buffer = if max_headway, do: max_headway, else: 0

        if Headway.HeadwayDisplay.show_first_departure?(
             first_departure,
             Timex.now(),
             time_buffer
           ) do
          {
            {config,
             %Content.Message.Headways.Top{
               destination: config.headway_destination,
               vehicle_type: vehicle_type(config.routes)
             }},
            {config, %Content.Message.Headways.Bottom{range: range}}
          }
        else
          {{config, Content.Message.Empty.new()}, {config, Content.Message.Empty.new()}}
        end

      {bottom, top} ->
        {{config,
          %Content.Message.Headways.Top{
            destination: config.headway_destination,
            vehicle_type: vehicle_type(config.routes)
          }},
         {config,
          %Content.Message.Headways.Bottom{
            range: {bottom, top},
            prev_departure_mins: nil
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
end
