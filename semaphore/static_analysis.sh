#!/usr/bin/env bash
set -e
set -x

MIX_ENV=test mix coveralls.json
bash <(curl -s https://codecov.io/bash) -t $REALTIME_SIGNS_CODECOV_TOKEN

# copy any pre-built PLTs to the right directory
find $SEMAPHORE_CACHE_DIR -name "dialyxir_*_deps-test.plt*" | xargs -I{} cp '{}' _build/test

MIX_ENV=test mix dialyzer --plt
# copy build PLTs back
cp _build/test/*_deps-test.plt* $SEMAPHORE_CACHE_DIR

MIX_ENV=test mix dialyzer --halt-exit-status
mix format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}" --check-formatted
