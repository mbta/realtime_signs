defmodule GTFS.Realtime do
  use Protobuf, from: Path.expand("../../config/gtfs-realtime.proto", __DIR__)
end
