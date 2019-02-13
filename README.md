# RealtimeSigns

[![Build Status](https://semaphoreci.com/api/v1/projects/39cb0e53-0299-441e-ab09-ddcb9fa9d2aa/1806488/badge.svg)](https://semaphoreci.com/mbta/realtime_signs)

Here's a general overview of the realtime_signs application which should be helpful for getting oriented to how things work. Please keep this up to date -- if you change something major in the code (build process, renaming modules, significant functionality changes, new configuration, etc.) document it here!

## Building and running the app

* `mix deps.get` to fetch dependencies.
* At this point you should be able to run `mix test` and get a clean build.
* To start the server, run `mix run --no-halt`. See "relevant environment variables" below for parameters you might want to pass to the server.

## Relevant environment variables

These can all be set with `export VARIABLE=value`, or e.g. `OCS_PORT=1234 iex -S mix`. Note that some are overridden completely in particular environments.

* `SIGN_HEAD_END_HOST`: hostname or IP of the head-end server that drives the actual physical signs, which `realtime_signs` pushes data to. Defaults to `172.20.145.28`, a test server.
* `SIGN_UI_URL`: hostname or IP of the instance of `signs_ui` to which `realtime_signs` pushes data. Defaults to `signs-dev.mbtace.com`, a test server.
* `SIGN_UI_API_KEY`: API key used when making requests to `signs_ui`. Not set by default.
* `BRIDGE_API_USERNAME` and `BRIDGE_API_PASSWORD`: credentials for the API that gets drawbridge status. Both default to a blank string.
* `TRIP_UPDATE_URL` and `VEHICLE_POSITIONS_URL`: URLs of the enhanced trip-update and vehicle-position feeds. Default to the real feed URLs.
* `API_V3_KEY` and `API_V3_URL`: Access key and URL for V3 API. Default respectively to a blank string and the URL of the dev-green API instance.
* `NUMBER_OF_HTTP_UPDATERS`: Number of `PaEss.HttpUpdater` processes that should run. These are responsible for posting updates to the PA/ESS head-end server, so this number is also the number of concurrent HTTP requests to that server.
