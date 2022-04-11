# RealtimeSigns

[![Build Status](https://semaphoreci.com/api/v1/projects/39cb0e53-0299-441e-ab09-ddcb9fa9d2aa/1806488/badge.svg)](https://semaphoreci.com/mbta/realtime_signs)

Here's a general overview of the realtime_signs application which should be helpful for getting oriented to how things work. Please keep this up to date -- if you change something major in the code (build process, renaming modules, significant functionality changes, new configuration, etc.) document it here!

## Building and running the app

* `mix deps.get` to fetch dependencies.
* At this point you should be able to run `mix test` and get a clean build.
* To start the server, run `mix run --no-halt`. See "relevant environment variables" below for parameters you might want to pass to the server.

## Relevant environment variables

[`WinSW 2.9`](https://github.com/winsw/winsw/releases/tag/v2.9.0) is used to update environment variables. This is done by by editing the XML file located in `/c/Users/RTRUser/apps/` for the respective Realtime Signs environment. Updates should also be made to the copy of the XML file in 1Password.

* `SIGN_HEAD_END_HOST`: hostname or IP of the head-end server that drives the actual physical signs, which `realtime_signs` pushes data to. Defaults to `127.0.0.1`, a test server.
* `SIGN_UI_URL`: hostname or IP of the instance of `signs_ui` to which `realtime_signs` pushes data. Defaults to `signs-dev.mbtace.com`, a test server.
* `SIGN_UI_API_KEY`: API key used when making requests to `signs_ui`. Not set by default.
* `TRIP_UPDATE_URL` and `VEHICLE_POSITIONS_URL`: URLs of the enhanced trip-update and vehicle-position feeds. Default to the real feed URLs.
* `API_V3_KEY` and `API_V3_URL`: Access key and URL for V3 API. Default respectively to a blank string and the URL of the dev-green API instance.
* `NUMBER_OF_HTTP_UPDATERS`: Number of `PaEss.HttpUpdater` processes that should run. These are responsible for posting updates to the PA/ESS head-end server, so this number is also the number of concurrent HTTP requests to that server.

After editing an environment variable's value and saving the XML file, restart service by finding `Realtime Signs (Dev/Prod)` in the Windows `Services` application and hitting `restart`. You don't need to build a new release if there are no code changes.

## Deploys

Realtime Signs (dev and prod) runs as Windows services on Opstech3, a virtual server hosted on hardware inside the MBTA network. You will need [VPN access](https://www.mbta.com/org/workfromhome) and [remote desktop access](https://github.com/mbta/wiki/blob/master/devops/accessing-windows-servers.md) to this server first.

### First-time steps

1. Grant your account access to the `RTRUser` account's home directory, where the code and compiled artifacts live. In Windows Explorer, navigate to `C:\Users\RTRUser` and you'll be prompted to change the permissions on the folder. From here on, you should be able to access it in Git Bash via the path `/c/Users/RTRUser` (or right-click on the folder and "Git Bash Here").

1. Generate a new SSH key and link it to your GitHub account. [Instructions are here](https://docs.github.com/en/github-ae@latest/github/authenticating-to-github/connecting-to-github-with-ssh); select "Linux" as your operating system and perform the steps in Git Bash.

### Deploying

To deploy a new version of the code:

1. In Git Bash, navigate to `/c/Users/RTRUser/GitHub/realtime_signs_release_[dev|prod]`
1. `git pull` the latest version
1. Run `./build_release.sh realtime_signs_[dev|prod]` to compile a new release. The second argument gives the name of the Erlang node to run the release under and isn't terribly important as long as it's distinct for dev versus prod.
1. Open the Windows `Services` application and restart `Realtime Signs (Dev/Prod)`
1. Tag the release in git: `git tag -a yyyy-mm-dd -m "Deployed on [date] at [time]"`
1. Push the tag to GitHub: `git push origin yyyy-mm-dd`

### Rolling back

To quickly roll back to a previous version:

* Move the broken release: `mv _build _build-broken`
* Restore the previous release: `mv _build-prev _build`
* Restart the service

### Setup details

The version of Erlang we use is precompiled Erlang/OTP 22.1, installed via [this Windows installer](https://www.erlang-solutions.com/resources/download.html) to `/c/Users/RTRUser/bin/`.

The version of Elixir we use is precompiled Elixir 1.9.4, downloaded [here](https://github.com/elixir-lang/elixir/releases) and unzipped to `/c/Users/RTRUser/bin`.

The `realtime_signs` code is `git clone`d to `/c/Users/RTRUser/GitHub/realtime_signs_release_[dev|prod]/`. (The repo is cloned twice, once for dev and once for prod.)

We build the application via Elixir-native `mix release`, setting the `PATH` to include the aforementioned versions of Elixir and Erlang. The release gets built into `_build/prod/rel/`.

To manage the Windows service we use [`WinSW 2.9`](https://github.com/winsw/winsw/releases/tag/v2.9.0). The service is configured via an XML file in `/c/Users/RTRUser/apps/`.
