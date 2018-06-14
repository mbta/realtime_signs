defmodule Positions.Positions do

  def parse_pb_response(body) do
    GTFS.Realtime.FeedMessage.decode(body)
  end

  def get_all(feed_message) do
    feed_message.entity
    |> Enum.filter(& &1.vehicle.current_status == :"STOPPED_AT")
    |> Enum.map(& {&1.vehicle.stop_id, true})
  end
end
