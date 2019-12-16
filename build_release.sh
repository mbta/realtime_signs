#!/usr/bin/env bash

# Run this from the repo root directory (e.g. /c/Users/RTRUser/GitHub/realtime_signs_release_dev)

MIX_ENV=prod
ERL_DIR="erl10.5"
ELIXIR_DIR="elixir1.9.4"
PATH="/c/Users/RTRUser/bin/$ERL_DIR/bin/:/c/Users/RTRUser/bin/$ELIXIR_DIR/bin/:$PATH"

rm -r _build/
mix deps.get
mix release

echo "Release is built. Restart the Windows service to run it."
