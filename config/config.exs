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
  sign_head_end_host: System.get_env("SIGN_HEAD_END_HOST") || "172.20.145.28",
  sign_ui_url: System.get_env("SIGN_UI_URL") || "signs-dev.mbtace.com",
  sign_ui_api_key: System.get_env("SIGN_UI_API_KEY"),
  time_zone: "America/New_York",
  bridge_requester: Bridge.Request,
  bridge_api_username: System.get_env("BRIDGE_API_USERNAME") || "",
  bridge_api_password: System.get_env("BRIDGE_API_PASSWORD") || "",
  trip_update_url: System.get_env("TRIP_UPDATE_URL") || "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json",
  vehicle_positions_url: System.get_env("VEHICLE_POSITIONS_URL") || "https://s3.amazonaws.com/mbta-gtfs-s3/rtr/VehiclePositions_enhanced.json",
  sign_updater_mod: PaEss.Logger,
  http_poster_mod: HTTPoison,
  headway_requester: Headway.Request,
  headway_calculator: Headway.ScheduleHeadway,
  external_config_getter: ExternalConfig.Local,
  aws_client: ExAws,
  s3_client: ExAws.S3,
  s3_bucket: System.get_env("SIGNS_S3_BUCKET"),
  s3_path: System.get_env("SIGNS_S3_PATH"),
  stopped_train_enabled?: (if System.get_env("STOPPED_TRAIN_ENABLED") == "true", do: true, else: false),
  green_line_enabled?: System.get_env("GREEN_LINE_ENABLED") == "true"

config :ex_aws,
  access_key_id: [{:system, "SIGNS_S3_CONFIG_KEY"}, :instance_role],
  secret_access_key: [{:system, "SIGNS_S3_CONFIG_SECRET"}, :instance_role]

config :logger,
  backends: [:console]

config :ehmon, :report_mf, {:ehmon, :info_report}

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
