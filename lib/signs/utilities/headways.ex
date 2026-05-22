defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  generates the top and bottom lines for the sign
  """
  require Logger

  # Process headways for Silver Line differently b/c of its different config shape
  def headway_message_sl(headway_group, headway_destination, stop_ids, current_time) do
    case fetch_headways(headway_group, stop_ids, current_time) do
      nil ->
        nil

      headways ->
        %Message.Headway{
          destination: headway_destination,
          range: {headways.range_low, headways.range_high},
          route: "Silver"
        }
    end
  end

  def fetch_headways(headway_group, stop_ids, current_time) do
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
