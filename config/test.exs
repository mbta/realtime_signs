use Mix.Config

config :realtime_signs,
  http_client: Fake.HTTPoison,
  trip_update_url: "https://fake_update/mbta-gtfs-s3/fake_trip_update.json",
  http_poster_mod: Fake.HTTPoison,
  headway_requester: Fake.Headway.Request,
  headway_calculator: Fake.Headway.ScheduleHeadway,
  bridge_requester: Fake.Bridge.Request,
  external_config_getter: Fake.ExternalConfig.Local,
  aws_client: Fake.ExAws,
  s3_client: Fake.ExAws
