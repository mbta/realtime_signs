defmodule RTR.Utilities.Time do
  @moduledoc """
  Some utility functions for dealing with times
  """

  @spec parse_schedule_time(String.t) :: integer | nil
  def parse_schedule_time(""), do: nil
  def parse_schedule_time(time) when is_binary(time) do
    case String.split(time, ":") do
      [hrs, mins, secs] ->
        String.to_integer(hrs) * 3600 + String.to_integer(mins) * 60 + String.to_integer(secs)
      [hrs, mins] ->
        String.to_integer(hrs) * 3600 + String.to_integer(mins) * 60
    end
  end

  def in_rtr_tz(datetime, timezone \\ Application.get_env(:realtime_signs, :time_zone))
  def in_rtr_tz(%NaiveDateTime{} = time, timezone) do
    Timex.to_datetime(time, timezone)
  end
  def in_rtr_tz(%Date{} = date, timezone) do
    Timex.to_datetime(date, timezone)
  end

  @spec local_now(Timex.Types.valid_timezone) :: DateTime.t | Timex.AmbiguousDateTime.t | {:error, term}
  def local_now(timezone \\ Application.get_env(:realtime_signs, :time_zone)) do
    Timex.now(timezone)
  end

  @spec get_seconds_since_midnight(NaiveDateTime.t | DateTime.t) :: integer
  def get_seconds_since_midnight(%NaiveDateTime{} = current_time) do
    current_time
    |> in_rtr_tz
    |> get_seconds_since_midnight
  end
  def get_seconds_since_midnight(%DateTime{} = current_time) do
    service_date = current_time
                   |> get_service_date
                   |> in_rtr_tz
    midnight = dst_safe_shift(Timex.set(service_date, hour: 12), hours: -12)
    Timex.diff(current_time, midnight, :seconds)
  end

  @spec seconds_since_midnight_to_date_time(DateTime.t, integer) :: DateTime.t
  def seconds_since_midnight_to_date_time(current_time, seconds_since_midnight) do
    service_date = current_time
                   |> get_service_date
                   |> in_rtr_tz
    midnight = dst_safe_shift(Timex.set(service_date, hour: 12), hours: -12)
    Timex.shift(midnight, seconds: seconds_since_midnight)
  end

  def get_service_date(current_time \\ local_now()) do
    datetime = Timex.beginning_of_day(current_time)
    service_datetime =
      if current_time.hour < 3 do
        Timex.shift(datetime, days: -1)
      else
        datetime
      end
    Timex.to_date(service_datetime)
  end

  def parse_calendar_date(date) do
    date
    |> Timex.parse!("%Y%m%d", :strftime)
    |> Timex.to_date
  end

  @spec dst_safe_shift(Timex.Types.valid_datetime, Timex.shift_options) :: DateTime.t
  def dst_safe_shift(datetime, options) do
    case Timex.shift(datetime, options) do
      %{after: dt} -> dt
      %{year: _} = dt -> dt
    end
  end

  @spec gtfs_delta(DateTime.t, integer) :: integer
  def gtfs_delta(time \\ local_now(), seconds_since_midnight) do
    seconds_from_midnight_to_now = get_seconds_since_midnight(time)
    seconds_since_midnight - seconds_from_midnight_to_now
  end
end
