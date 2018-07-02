defmodule GTFS.Realtime do
  use Protobuf, from: Path.expand("../../config/gtfs-realtime.proto", __DIR__)
  @type feed_entity :: %__MODULE__.FeedEntity{}
  @type feed_message :: %__MODULE__.FeedMessage{}
end
