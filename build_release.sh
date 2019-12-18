#!/usr/bin/env bash

# Run this from the repo root directory (e.g. /c/Users/RTRUser/GitHub/realtime_signs_release_dev)

ERL_DIR="erl10.5"
ELIXIR_DIR="elixir1.9.4"

rm -r _build/
env MIX_ENV=prod PATH="/c/Users/RTRUser/bin/$ERL_DIR/bin/:/c/Users/RTRUser/bin/$ELIXIR_DIR/bin/:$PATH" mix deps.get
env MIX_ENV=prod PATH="/c/Users/RTRUser/bin/$ERL_DIR/bin/:/c/Users/RTRUser/bin/$ELIXIR_DIR/bin/:$PATH" mix release

echo "Release is built. Restart the Windows service to run it."
