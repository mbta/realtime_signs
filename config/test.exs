use Mix.Config

config :realtime_signs,
  http_client: Fake.HTTPoison,
  stations_config: "test/data/stations.json"
