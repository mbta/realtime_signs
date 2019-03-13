defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig
  require Logger
  @alert_headway_bump 3

  @spec get_messages(Signs.Realtime.t()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_messages(sign) do
    cond do
      config = single_source_config(sign) ->
        do_headway_messages(sign, config)

      config = config_by_headway_id(sign) ->
        do_headway_messages(sign, config)

      true ->
        {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end
  end

  @spec do_headway_messages(Signs.Realtime.t(), map()) ::
          {{map(), Content.Message.t()}, {map(), Content.Message.t()}}
  defp do_headway_messages(sign, config) do
    headway_range = sign.headway_engine.get_headways(config.stop_id)

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

      {:first_departure, _, _} ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {bottom, top} ->
        adjusted_range =
          if alert_status != :none do
            Logger.info("headway_bump #{sign.id}")
            {if(bottom, do: bottom + @alert_headway_bump), if(top, do: top + @alert_headway_bump)}
          else
            {bottom, top}
          end

        {{config,
          %Content.Message.Headways.Top{
            headsign: config.headway_direction_name,
            vehicle_type: vehicle_type(config.routes)
          }}, {config, %Content.Message.Headways.Bottom{range: adjusted_range}}}
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
