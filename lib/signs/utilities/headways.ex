defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig
  require Logger

  @spec headway_messages(SourceConfig.config(), DateTime.t()) ::
          Signs.Realtime.sign_messages() | nil
  def headway_messages(config, current_time) do
    case fetch_headways(config.headway_group, config.sources, current_time) do
      nil ->
        nil

      headways ->
        {%Content.Message.Headways.Top{
           destination: config.headway_destination,
           route: SourceConfig.single_route(config)
         }, %Content.Message.Headways.Bottom{range: {headways.range_low, headways.range_high}}}
    end
  end

  @spec headway_message(SourceConfig.config(), DateTime.t()) ::
          Signs.Realtime.line_content() | nil
  def headway_message(config, current_time) do
    case fetch_headways(config.headway_group, config.sources, current_time) do
      nil ->
        nil

      headways ->
        %Content.Message.Headways.Paging{
          destination: config.headway_destination,
          range: {headways.range_low, headways.range_high},
          route: SourceConfig.single_route(config)
        }
    end
  end

  defp fetch_headways(headway_group, sources, current_time) do
    stop_ids = Enum.map(sources, & &1.stop_id)

    with headways when not is_nil(headways) <-
           RealtimeSigns.config_engine().headway_config(headway_group, current_time),
         true <-
           RealtimeSigns.headway_engine().display_headways?(stop_ids, current_time, headways) do
      headways
    else
      _ -> nil
    end
  end
end
