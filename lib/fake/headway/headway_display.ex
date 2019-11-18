defmodule Fake.Headway.HeadwayDisplay do
  require Logger

  def group_headways_for_stations(schedules, station_ids, current_time) do
    Logger.info("group_headways_for_stations called")
    Headway.HeadwayDisplay.group_headways_for_stations(schedules, station_ids, current_time)
  end
end
