# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :realtime_signs, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:realtime_signs, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

config :realtime_signs,
  http_client: HTTPoison,
  posts_log_dir: "log/posts/",
  sign_head_end_host: "127.0.0.1",
  sign_ui_url: "signs-dev.mbtace.com",
  sign_ui_api_key: nil,
  time_zone: "America/New_York",
  bridge_requester: Bridge.Request,
  bridge_api_username: "",
  bridge_api_password: "",
  trip_update_url: "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json",
  vehicle_positions_url:
    "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/VehiclePositions_enhanced.json",
  sign_updater_mod: PaEss.Logger,
  http_poster_mod: HTTPoison,
  scheduled_headway_requester: Headway.Request,
  headway_calculator: Headway.HeadwayDisplay,
  external_config_getter: ExternalConfig.Local,
  aws_client: ExAws,
  s3_client: ExAws.S3,
  s3_bucket: nil,
  s3_path: nil,
  api_v3_key: nil,
  api_v3_url: "https://green.dev.api.mbtace.com",
  number_of_http_updaters: 4

config :ex_aws,
  access_key_id: [{:system, "SIGNS_S3_CONFIG_KEY"}, :instance_role],
  secret_access_key: [{:system, "SIGNS_S3_CONFIG_SECRET"}, :instance_role]

config :logger, backends: [:console]

config :ehmon, :report_mf, {:ehmon, :info_report}

config :sentry, json_library: Jason

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env()}.exs"
