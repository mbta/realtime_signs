use Mix.Config

config :realtime_signs,
  http_client: Fake.Finch,
  trip_update_url: "https://fake_update/mbta-gtfs-s3/fake_trip_update.json",
  http_poster_mod: Fake.Finch,
  scheduled_headway_requester: Fake.Headway.Request,
  headway_calculator: Fake.Headway.HeadwayDisplay,
  external_config_getter: Fake.ExternalConfig.Local,
  aws_client: Fake.ExAws,
  s3_client: Fake.ExAws

config :realtime_signs, http_pool_config: %{
    :default => [size: 25]
  }
