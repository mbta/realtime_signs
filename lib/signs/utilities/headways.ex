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
    case single_source_config(sign) do
      nil ->
        {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}

      config ->
        do_headway_messages(sign, config)
    end
  end

  defp do_headway_messages(sign, config) do
    headway_range = sign.headway_engine.get_headways(config.stop_id)

    {{config,
      %Content.Message.Headways.Top{
        headsign: config.headway_direction_name,
        vehicle_type: vehicle_type(config.routes)
      }}, {config, %Content.Message.Headways.Bottom{range: headway_range}}}
  end

  defp vehicle_type(["743"]), do: :bus
  defp vehicle_type(_), do: :train

  defp single_source_config(sign) do
    case sign.source_config do
      {[one]} -> one
      _ -> nil
    end
  end
end
