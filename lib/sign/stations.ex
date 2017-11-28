defmodule Sign.Stations do
  @moduledoc """
  Responsible for dealing with station information for signs, including converting from GTFS stop IDs.
  """

  alias Sign.Station

  @doc """
  PA information for the given GTFS stop. Returns `nil` if we don't have any
  info configured/enabled.
  """
  def pa_info(gtfs_stop_id) do
    pa_info = Sign.Stations.Live.for_gtfs_id(gtfs_stop_id)
    if not is_nil(pa_info) && pa_info.enabled?, do: pa_info, else: nil
  end

  @doc """
  Which line to display an arrival on based on its order and the direction ID
  of the trip.
  """
  def display_line(%Station{display_type: {:one_line, line}}) do
    line
  end
  def display_line(pa_info, direction_id, arrival_number) do
    cond do
      pa_info.display_type == :separate -> arrival_number
      direction_id == 0 -> :top
      direction_id == 1 -> :bottom
    end
  end
end
