defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig

  @spec get_messages(Signs.Realtime.t()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_messages(sign) do
    cond do
      config = config_by_headway_id(sign) ->
        do_headway_messages(sign, config)

      config = single_source_config(sign) ->
        do_headway_messages(sign, config)

      true ->
        {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end
  end

  @spec do_headway_messages(Signs.Realtime.t(), map()) ::
          {{map(), Content.Message.t()}, {map(), Content.Message.t()}}
  defp do_headway_messages(sign, config) do
    headway_range = sign.headway_engine.get_headways(config.stop_id)

    case headway_range do
      :none ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {nil, nil} ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {:first_departure, _, _} ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      headway_range ->
        {{config,
          %Content.Message.Headways.Top{
            headsign: config.headway_direction_name,
            vehicle_type: vehicle_type(config.routes)
          }}, {config, %Content.Message.Headways.Bottom{range: headway_range}}}
    end
  end

  defp vehicle_type(["743"]), do: :bus
  defp vehicle_type(_), do: :train

  defp config_by_headway_id(sign) do
    if sign.headway_stop_id do
      sign.source_config
      |> Tuple.to_list()
      |> List.flatten()
      |> Enum.find(&(&1.stop_id == sign.headway_stop_id))
    else
      nil
    end
  end

  defp single_source_config(sign) do
    case sign.source_config do
      {[one]} -> one
      _ -> nil
    end
  end
end
