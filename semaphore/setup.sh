#!/usr/bin/env bash
set -e

mix local.hex --force
mix local.rebar --force
MIX_ENV=test mix do deps.get, deps.compile
MIX_ENV=test mix compile --warnings-as-errors --force
