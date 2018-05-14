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
end
