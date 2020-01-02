#!/usr/bin/env bash
set -e

# Run this from the repo root directory (e.g. /c/Users/RTRUser/GitHub/realtime_signs_release_dev)
# Takes the release node name as an argument (e.g. `$ ./build_release.sh realtime_signs_dev`)

if [ $# -eq 0 ]; then
  echo "No argument provided"
  exit 1
fi

ERL_DIR="erl10.5"
ELIXIR_DIR="elixir1.9.4"

env MIX_ENV=prod PATH="/c/Users/RTRUser/bin/$ERL_DIR/bin/:/c/Users/RTRUser/bin/$ELIXIR_DIR/bin/:$PATH" mix deps.get
env MIX_ENV=prod PATH="/c/Users/RTRUser/bin/$ERL_DIR/bin/:/c/Users/RTRUser/bin/$ELIXIR_DIR/bin/:$PATH" RELEASE_NODE=$1 mix release

echo "Release is built. Restart the Windows service to run it."
