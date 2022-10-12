ARG ELIXIR_VERSION=1.12.3
ARG ERLANG_VERSION=22.3
ARG WINDOWS_VERSION=1809
# See also: ERTS_VERSION in the from image below

ARG BUILD_IMAGE=mbtatools/windows-elixir:$ELIXIR_VERSION-erlang-$ERLANG_VERSION-windows-$WINDOWS_VERSION
ARG FROM_IMAGE=mcr.microsoft.com/windows/servercore:$WINDOWS_VERSION

FROM $BUILD_IMAGE as build

ENV MIX_ENV=prod

# log which version of Windows we're using
RUN ver
