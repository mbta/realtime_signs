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
  sign_updater: Sign.Updater,
  stations_config: System.get_env("STATIONS_CONFIG") || "config/stations.json",
  time_zone: "America/New_York"

config :logger,
  backends: [:console]

config :logger, :splunk,
  connector: Logger.Backend.Splunk.Output.Http,
  host: 'https://http-inputs-mbta.splunkcloud.com/services/collector/event',
  token: {:system, "STAGING_SIGNS_SPLUNK_TOKEN"},
  format: "$dateT$time [$level]$levelpad $metadata$message\n",
  metadata: [:request_id]

config :ehmon, :report_mf, {:ehmon, :info_report}

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
