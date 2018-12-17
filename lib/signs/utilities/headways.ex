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
    case SourceConfig.sign_stop_ids(sign.source_config) do
      [stop_id] ->
        do_headway_messages(sign, stop_id)

      _ ->
        {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end
  end

  defp do_headway_messages(sign, stop_id) do
    config = source_config(sign)
    headway_range = sign.headway_engine.get_headways(stop_id)

    if config do
      {{config,
        %Content.Message.Headways.Top{
          headsign: config.headway_direction_name,
          vehicle_type: vehicle_type(config.routes)
        }}, {config, %Content.Message.Headways.Bottom{range: headway_range}}}
    else
      {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end
  end

  defp vehicle_type(["Mattapan"]), do: :trolley
  defp vehicle_type(["743"]), do: :bus
  defp vehicle_type(_), do: :train

  defp source_config(sign) do
    case sign.source_config do
      {[one]} -> one
      {_, _} -> nil
    end
  end
end
