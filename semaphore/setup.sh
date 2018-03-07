#!/usr/bin/env bash
set -e

mix local.hex --force
mix local.rebar --force
mix deps.get --only test
mix compile --warnings-as-errors --force
