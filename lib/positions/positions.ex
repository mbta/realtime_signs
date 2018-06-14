defmodule Positions.Positions do
  @moduledoc """
  Maintains an up-to-date internal state of a list of gtfs_stop_ids
  that currently have a stopped vehicle at them.
  Fetches from the GTFS-RT PB file about once per second.
  """

  @spec parse_pb_response(binary) :: map()
  def parse_pb_response(body) do
    GTFS.Realtime.FeedMessage.decode(body)
  end

  @spec get_stopped(map) :: [{String.t, true}]
  def get_stopped(feed_message) do
    feed_message.entity
    |> Enum.filter(& &1.vehicle.current_status == :STOPPED_AT)
    |> Enum.map(& {&1.vehicle.stop_id, true})
  end
end
