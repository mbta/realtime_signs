# RealtimeSigns

Here's a general overview of the realtime_signs (RTS) application which should be helpful for getting oriented to how things work. Please keep this up to date -- if you change something major in the code (build process, renaming modules, significant functionality changes, new configuration, etc.) document it here!

## Prerequisites

* [asdf](https://asdf-vm.com/)
* [direnv](https://direnv.net/)

## Development

* If it's your first time using asdf, run `asdf plugin add erlang && asdf plugin add elixir`.
* Run `asdf install` from the repository root.
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

## Environment variables

The application needs several environment variables to access external services. See `.envrc.template` for documentation. When running locally, these variables are provided by `direnv`. In deployed environments, they are provided by AWS Secrets Manager. When adding new environment variables, make sure to add them to both locations, as appropriate.

## Deploying

Realtime Signs runs on on-prem servers. Deployments are managed with ECS Anywhere, which allows us to manage RTS deployments on those on-prem servers. Deployments are initiated through the following GitHub Actions:

- [Deploy to Dev Green](/.github/workflows/dev-green.yml)
- [Deploy to Dev](/.github/workflows/dev.yml)
- [Deploy to Prod](/.github/workflows/prod.yml)

Deployment actions require the following repository secrets to be set in GitHub:

    AWS_ROLE_ARN
    DOCKER_REPO (the ECR repository to push images into)
    SLACK_WEBHOOK
