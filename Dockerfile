ARG ELIXIR_VERSION=1.14.0
ARG ERLANG_VERSION=25.0.4
ARG WINDOWS_VERSION=1809
# See also: ERTS_VERSION in the from image below

ARG BUILD_IMAGE=mbtatools/windows-elixir:$ELIXIR_VERSION-erlang-$ERLANG_VERSION-windows-$WINDOWS_VERSION
ARG FROM_IMAGE=mcr.microsoft.com/windows/servercore:$WINDOWS_VERSION

FROM $BUILD_IMAGE as build

ENV MIX_ENV=prod

# log which version of Windows we're using
RUN ver

RUN mkdir C:\realtime_signs

WORKDIR C:\\realtime_signs

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config/config.exs config\\config.exs
COPY config/prod.exs config\\prod.exs

RUN mix deps.compile

COPY lib lib
COPY priv priv

COPY config/runtime.exs config\\runtime.exs
RUN mix release

FROM $FROM_IMAGE
ARG ERTS_VERSION=10.7

USER ContainerAdministrator
COPY --from=build C:\\Erlang\\vcredist_x64.exe vcredist_x64.exe
RUN .\vcredist_x64.exe /install /quiet /norestart \
    && del vcredist_x64.exe

COPY --from=build C:\\realtime_signs\\_build\\prod\\rel\\realtime_signs C:\\realtime_signs

WORKDIR C:\\realtime_signs

# Ensure Erlang can run
RUN dir && \
    erts-%ERTS_VERSION%\bin\erl -noshell -noinput +V

EXPOSE 80
CMD ["C:\\realtime_signs\\bin\\realtime_signs.bat", "start"]
