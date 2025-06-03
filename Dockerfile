ARG ALPINE_VERSION=3.21.3
ARG ELIXIR_VERSION=1.17.3
ARG ERLANG_VERSION=27.3.4
# See also: ERTS_VERSION in the from image below

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} AS build

ENV MIX_ENV=prod

RUN mkdir /realtime_signs

WORKDIR /realtime_signs

RUN apk add --no-cache git
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config/config.exs config/config.exs
COPY config/prod.exs config/prod.exs

RUN mix deps.compile

COPY lib lib
COPY priv priv

COPY config/runtime.exs config/runtime.exs
RUN mix release linux

# The one the elixir image was built with
FROM hexpm/erlang:${ERLANG_VERSION}-alpine-${ALPINE_VERSION}

RUN apk add --no-cache dumb-init && \
    mkdir /work /realtime_signs && \
    adduser -D realtime_signs && \
    chown realtime_signs /work

COPY --from=build /realtime_signs/_build/prod/rel/linux /realtime_signs

RUN chown realtime_signs /realtime_signs/lib/tzdata-*/priv /realtime_signs/lib/tzdata*/priv/*

# Set exposed ports
ENV MIX_ENV=prod TERM=xterm LANG=C.UTF-8 \
    ERL_CRASH_DUMP_SECONDS=0 RELEASE_TMP=/work

USER realtime_signs
WORKDIR /work

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

HEALTHCHECK CMD ["/realtime_signs/bin/linux", "rpc", "1 + 1"]
CMD ["/realtime_signs/bin/linux", "start"]
