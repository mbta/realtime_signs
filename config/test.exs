use Mix.Config

config :realtime_signs,
  http_client: Fake.HTTPoison,
  stations_config: "test/data/stations.json",
  trip_update_url: "https://fake_update/mbta-gtfs-s3/fake_trip_update.pb",
  http_poster_mod: Fake.HTTPoison,
  headway_requester: Fake.Headway.Request
