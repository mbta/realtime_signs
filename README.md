# RealtimeSigns

Here's a general overview of the realtime_signs application which should be helpful for getting oriented to how things work. Please keep this up to date -- if you change something major in the code (build process, renaming modules, significant functionality changes, new configuration, etc.) document it here!

## Prerequisites

* [asdf](https://asdf-vm.com/)
* [direnv](https://direnv.net/)

## Development

* If it's your first time using asdf, run `asdf plugin add erlang && asdf plugin add elixir`.
* Run `asdf install` from the repository root.
  <!-- Remove this if upgrading the Erlang/OTP version beyond 25 -->
  * Note: If running macOS Sonoma on an Apple Silicon (ARM) machine, use `KERL_CONFIGURE_OPTIONS="--disable-jit" asdf install`[^1]
* `mix deps.get` to fetch dependencies.
* At this point you should be able to run `mix test` and get a clean build.
* Copy `.envrc.template` to `.envrc`, then edit `.envrc` and make sure all required environment variables are set. When finished, run `direnv allow` to activate them.
* To start the server, run `mix run --no-halt`.

### Developing locally with [signs_ui](https://github.com/mbta/signs_ui)

First, ensure you have a basic working environment as described above, and in the signs_ui README.
1. Start signs_ui and tell it what API key to accept: `MESSAGES_API_KEYS=realtime_signs:a6975e41192b888c NODE_ENV=development mix run --no-halt`. The key is arbitrary but it must match what you provide in the next step.
2. Edit `.envrc` and ensure that `SIGN_UI_URL`, `SIGN_UI_API_KEY`, and `SIGN_CONFIG_FILE` are configured to point to the local signs_ui.
3. Start realtime_signs.
4. Open up http://localhost:5000 and you should see the signs data being populated by your local app.

### Running locally in a docker container
If you need to run realtime signs in a local docker container, there are a few extra steps you'll need to take.

1. Follow the instructions in [this notion doc](https://www.notion.so/mbta-downtown-crossing/Creating-debugging-a-Windows-Docker-container-2f21af809c894aab8038d12ae9c54361) for your OS to set up docker
2. Once docker is running on either your Windows machine or your Windows VM, run `docker build .` in the root directory of realtime_signs.
3. In order to run the image, you'll need a number of env variables. It's probably easiest to add a env.list file to your local repo containing the neeed values. You can read about setting env variables in a container [here](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file)
4. Run the image in a container with `docker run --env-file env.list [IMAG TAG]`

## Environment variables

The application needs several environment variables to access external services. See `.envrc.template` for documentation. When running locally, these variables are provided by `direnv`. In deployed environments, they are provided by AWS Secrets Manager. When adding new environment variables, make sure to add them to both locations, as appropriate.

## Deploying

Realtime Signs (dev and prod) runs as a Docker Swarm service in the MBTA's data center. Deployments happen from GitHub Actions (the Deploy to Dev and Deploy to Prod actions).

It requires repository secrets to be set in GitHub:

    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    DOCKER_REPO (the ECR repository to push images into)



[^1]: The way memory is allocated for the JIT in OTP 25 is prohibited in macOS Sonomoa. [Disabling the JIT fixes the issue](https://github.com/erlang/otp/issues/7687#issuecomment-1737184968). This has [been fixed in OTP-25.3.2.7](https://github.com/erlang/otp/commit/ac591a599b09b48b45a7125aa30ec5419ba3cc2f) and beyond.
