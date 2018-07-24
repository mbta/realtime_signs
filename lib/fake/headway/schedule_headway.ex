defmodule Fake.Headway.ScheduleHeadway do
  require Logger

  def group_headways_for_stations(schedules, station_ids, current_time) do
    Logger.info("group_headways_for_stations called")
    Headway.ScheduleHeadway.group_headways_for_stations(schedules, station_ids, current_time)
  end
end
