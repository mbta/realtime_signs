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

## Deploys

Realtime signs (dev and prod) run as a Windows services on Opstech3.

On Opstech3 there is a user, `RTRUser` where the code and compiled artifacts live. In order to access `/c/Users/RTRUser/` in Git Bash, you will have to navigate to the directory in the Windows GUI Explorer. The first time you open it, it will prompt you for permissions, and then after that you'll have access via Git Bash.

The version of Erlang we use is precompiled Erlang/OTP 22.1, installed via [this Windows installer](https://www.erlang-solutions.com/resources/download.html) to `/c/Users/RTRUser/bin/`.

The version of Elixir we use is precompiled Elixir 1.9.4, downloaded [here](https://github.com/elixir-lang/elixir/releases) and unzipped to `/c/Users/RTRUser/bin`.

The `realtime_signs` code is `git clone`d to `/c/Users/RTRUser/GitHub/realtime_signs_release_[dev/prod]/`. (The repo is cloned twice, once for dev and once for prod.)

We build the application via Elixir-native `mix release`, setting the `PATH` to include the aforementioned versions of Elixir and Erlang. The release gets built into `_build/prod/rel/`.

To manage the Windows service we use [`nssm`](https://nssm.cc/). The service is configured via `nssm edit realtime-signs-[prod/staging]`. In particular, environment variables are added there, and the app launch is configured there. The app is configured to launch as follows:

* `Path`: `C:\Users\RTRUser\GitHub\realtime_signs_release_[dev/prod]\_build\prod\rel\realtime_signs\bin\realtime_signs.bat`
* `Startup directory`: `C:\Users\RTRUser\GitHub\realtime_signs_release_[dev/prod]`
* `Arguments`: `start`

To deploy a new version of the code:

1. In Git Bash, navigate to `/c/Users/RTRUser/GitHub/realtime_signs_release_[dev/prod]`
1. `git pull` the latest version
1. Run `./build_release.sh` to compile a new release.
1. Open the Windows `Services` application and restart `realtime-signs-[staging/prod]`
