# RealtimeSigns

Here's a general overview of the realtime_signs application which should be helpful for getting oriented to how things work. Please keep this up to date -- if you change something major in the code (build process, renaming modules, significant functionality changes, new configuration, etc.) document it here!

## Development

* Run `asdf install` from the repository root.
* `mix deps.get` to fetch dependencies.
* At this point you should be able to run `mix test` and get a clean build.
* To start the server, run `mix run --no-halt`. See "relevant environment variables" below for parameters you might want to pass to the server.

### Developing locally with [signs_ui](https://github.com/mbta/signs_ui)

First, ensure you have a basic working environment as described above, and in the signs_ui README.
1. Start signs_ui and tell it what API key to accept: `MESSAGES_API_KEYS=realtime_signs:a6975e41192b888c NODE_ENV=development mix run --no-halt`. The key is arbitrary but it must match what you provide in the next step.
2. Start realtime_signs, and provide the local URL and API key, as well as the location of the config file: `SIGN_UI_URL=localhost:5000 SIGN_UI_API_KEY=a6975e41192b888c SIGN_CONFIG_FILE=../signs_ui/priv/config.json mix run --no-halt`
3. Open up http://localhost:5000 and you should see the signs data being populated by your local app.

### Running locally in a docker container
If you need to run realtime signs in a local docker container, there are a few extra steps you'll need to take.

1. Follow the instructions in [this notion doc](https://www.notion.so/mbta-downtown-crossing/Creating-debugging-a-Windows-Docker-container-2f21af809c894aab8038d12ae9c54361) for your OS to set up docker
2. Once docker is running on either your Windows machine or your Windows VM, run `docker build .` in the root directory of realtime_signs.
3. In order to run the image, you'll need a number of env variables. It's probably easiest to add a env.list file to your local repo containing the neeed values. You can read about setting env variables in a container [here](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file)
4. Run the image in a container with `docker run --env-file env.list [IMAG TAG]`

## Environment variables
Environment variables are stored in AWS Secrets Manager. If a new env variable needs to be added, Secrets Manager will need to be updated and then the application will need to be re-deployed.

### Relevant Environment Variables

* `SIGN_HEAD_END_HOST`: hostname or IP of the head-end server that drives the actual physical signs, which `realtime_signs` pushes data to. Leave empty to skip the physical sign update.
* `SIGN_UI_URL`: hostname or IP of the instance of `signs_ui` to which `realtime_signs` pushes data. Leave empty to skip updating the UI.
* `SIGN_UI_API_KEY`: API key used when making requests to `signs_ui`. Not set by default.
* `TRIP_UPDATE_URL` and `VEHICLE_POSITIONS_URL`: URLs of the enhanced trip-update and vehicle-position feeds. Default to the real feed URLs.
* `API_V3_KEY` and `API_V3_URL`: Access key and URL for V3 API. Default respectively to a blank string and the URL of the dev-green API instance.
* `CHELSEA_BRIDGE_URL` and `CHELSEA_BRIDGE_AUTH`: URL and auth key for the Chelsea bridge API. These values can be found in the shared 1Password vault, in the "Chelsea Street Bridge Application" entry, in fields `url` and `auth`.
* `NUMBER_OF_HTTP_UPDATERS`: Number of `PaEss.HttpUpdater` processes that should run. These are responsible for posting updates to the PA/ESS head-end server, so this number is also the number of concurrent HTTP requests to that server.

## Deploying

Realtime Signs (dev and prod) runs as a Docker Swarm service in the MBTA's data center. Deployments happen from GitHub Actions (the Deploy to Dev and Deploy to Prod actions).

It requires repository secrets to be set in GitHub:

    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    DOCKER_REPO (the ECR repository to push images into)
