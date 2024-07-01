import Config

config :realtime_signs,
  http_client: Fake.HTTPoison,
  trip_update_url: "https://fake_update/mbta-gtfs-s3/fake_trip_update.json",
  sign_head_end_host: "signs.example.com",
  sign_ui_url: "signs-ui.example.com",
  api_v3_url: "https://api-dev-green.mbtace.com",
  http_poster_mod: Fake.HTTPoison,
  scheduled_headway_requester: Fake.Headway.Request,
  external_config_getter: Fake.ExternalConfig.Local,
  sign_config_file: "priv/config.json",
  aws_client: Fake.ExAws,
  s3_client: Fake.ExAws,
  screenplay_base_url: "fake-screenplay.com"
