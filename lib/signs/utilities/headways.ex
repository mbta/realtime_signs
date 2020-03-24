defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig
  require Logger

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
    case sign.config_engine.headway_config(sign.headway_group, current_time) do
      nil ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      %Engine.Config.Headway{} = headway ->
        stop_id = sign.headway_stop_id || config.stop_id
        buffer_mins = headway.range_high

        if sign.headway_engine.display_headways?(stop_id, current_time, buffer_mins) do
          {{config,
            %Content.Message.Headways.Top{
              destination: config.headway_destination,
              vehicle_type: :train
            }},
           {config,
            %Content.Message.Headways.Bottom{
              range: {headway.range_low, headway.range_high},
              prev_departure_mins: nil
            }}}
        else
          {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}
        end
    end
  end

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
