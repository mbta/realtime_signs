# RealtimeSigns

Here's a general overview of the realtime_signs application which should be helpful for getting oriented to how things work. Please keep this up to date -- if you change something major in the code (build process, renaming modules, significant functionality changes, new configuration, etc.) document it here!

## Development

* Run `asdf install` from the repository root.
* `mix deps.get` to fetch dependencies.
* At this point you should be able to run `mix test` and get a clean build.
* To start the server, run `mix run --no-halt`. See "relevant environment variables" below for parameters you might want to pass to the server.

## Environment variables
Environment variables are stored in AWS Secrets Manager. If a new env variable needs to be added, Secrets Manager will need to be updated and then the application will need to be re-deployed.

### Relevant Environment Variables

* `SIGN_HEAD_END_HOST`: hostname or IP of the head-end server that drives the actual physical signs, which `realtime_signs` pushes data to. Defaults to `127.0.0.1`, a test server.
* `SIGN_UI_URL`: hostname or IP of the instance of `signs_ui` to which `realtime_signs` pushes data. Defaults to `signs-dev.mbtace.com`, a test server.
* `SIGN_UI_API_KEY`: API key used when making requests to `signs_ui`. Not set by default.
* `TRIP_UPDATE_URL` and `VEHICLE_POSITIONS_URL`: URLs of the enhanced trip-update and vehicle-position feeds. Default to the real feed URLs.
* `API_V3_KEY` and `API_V3_URL`: Access key and URL for V3 API. Default respectively to a blank string and the URL of the dev-green API instance.
* `NUMBER_OF_HTTP_UPDATERS`: Number of `PaEss.HttpUpdater` processes that should run. These are responsible for posting updates to the PA/ESS head-end server, so this number is also the number of concurrent HTTP requests to that server.

## Deploying

Realtime Signs (dev and prod) runs as a Docker Swarm service in the MBTA's data center. Deployments happen from GitHub Actions (the Deploy to Dev and Deploy to Prod actions).

It requires repository secrets to be set in GitHub:

    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    DOCKER_REPO (the ECR repository to push images into)
