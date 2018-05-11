defmodule GTFS.Realtime do
  use Protobuf, from: Path.expand("../../priv/gtfs-realtime.proto", __DIR__)
end
