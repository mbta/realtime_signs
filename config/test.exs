import Config

config :realtime_signs,
  http_client: Fake.HTTPoison,
  trip_update_url: "https://fake_update/mbta-gtfs-s3/fake_trip_update.json",
  sign_head_end_host: "signs.example.com",
  sign_ui_url: "signs-ui.example.com",
  http_poster_mod: Fake.HTTPoison,
  scheduled_headway_requester: Fake.Headway.Request,
  headway_calculator: Fake.Headway.HeadwayDisplay,
  external_config_getter: Fake.ExternalConfig.Local,
  aws_client: Fake.ExAws,
  s3_client: Fake.ExAws
