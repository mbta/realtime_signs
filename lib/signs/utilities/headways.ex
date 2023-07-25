defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig
  require Logger

  @spec get_messages(Signs.Realtime.t(), DateTime.t()) :: Signs.Realtime.sign_messages()
  def get_messages(sign, current_time) do
    {sources, group, destination} =
      case sign.source_config do
        {top, bottom} -> {top.sources ++ bottom.sources, top.headway_group, nil}
        single -> {single.sources, single.headway_group, single.headway_destination}
      end

    case fetch_headways(sign, group, sources, current_time) do
      nil ->
        {%Content.Message.Empty{}, %Content.Message.Empty{}}

      headways ->
        if Signs.Utilities.SourceConfig.multi_source?(sign.source_config) do
          {%Content.Message.Headways.Top{
             routes:
               SourceConfig.sign_routes(sign.source_config)
               |> PaEss.Utilities.get_unique_routes(),
             vehicle_type: :train
           },
           %Content.Message.Headways.Bottom{
             range: {headways.range_low, headways.range_high}
           }}
        else
          {%Content.Message.Headways.Top{destination: destination, vehicle_type: :train},
           %Content.Message.Headways.Bottom{
             range: {headways.range_low, headways.range_high}
           }}
        end
    end
  end

  @spec get_paging_message(Signs.Realtime.t(), SourceConfig.config(), DateTime.t()) ::
          Signs.Realtime.line_content()
  def get_paging_message(sign, config, current_time) do
    case fetch_headways(sign, config.headway_group, config.sources, current_time) do
      nil ->
        %Content.Message.Empty{}

      headways ->
        %Content.Message.Headways.Paging{
          destination: config.headway_destination,
          range: {headways.range_low, headways.range_high}
        }
    end
  end

  defp fetch_headways(sign, headway_group, sources, current_time) do
    stop_ids = Enum.map(sources, & &1.stop_id)

    with headways when not is_nil(headways) <-
           sign.config_engine.headway_config(headway_group, current_time),
         true <-
           sign.headway_engine.display_headways?(stop_ids, current_time, headways.range_high) do
      headways
    else
      _ -> nil
    end
  end
end
