# Architecture

This document describes the high-level architecture of realtime_signs. The goal of this document
is to provide a useful orientation to a new contributor to the codebase.

## Application description

Realtime Signs is the app that puts subway countdown predictions on the black and yellow
Daktronics LED signs in and around stations. It does this by continually (about 1/sec) downloading
GTFS-rt data and sending HTTP POST requests as necessary to the ARINC head end server, which in
turn sends requests to the Station Control Units that control the signs at each station.

## Process-level architecture

The smallest granularity with which we can address signs in a station is called the "zone". Each
station can have up to six zones: north, south, east, west, center, and mezzanine. The zones names
are mnemonics but may not reflect the real layout of the station. But generally, "east", "west",
"north", and "south" zones refer to signs that display two lines of data for trains heading in
that direction (e.g. on platforms), _not_ signs located in that part of the station. We use N/S
for Red and Orange lines, and E/W for Green and Blue lines. "mezzanine" usually refers to signs on
the upper level of two-story stations, and "center" refers to signs on island platforms. Each zone
throughout the system has its own dedicated Elixir process, a `Signs.Realtime` GenServer
configured at start-up via `priv/signs.json`. See `Signs.Utilities.SourceConfig` for documentation
of the format of the `signs.json` file.

While a given zone may have multiple physical signs, that multiplicity is hidden from us. We only
ever can address the zone as a whole. As such, throughout this document and in comments and
identifiers in the app, we generally talk about a "sign", by which we mean a `Signs.Realtime`
process that represents all of the identical physical signs in the zone.

There are several "Engine" GenServers, responsible for maintaining various bits of data: alerts,
predictions, signs-ui configuration, etc. Each sign queries the engines once per tick (roughly
1/sec) to see if its content needs to change.

To prevent DOSing the ARINC head-end server, each sign does not send HTTP requests to it directly.
Rather, there's a `MessageQueue` GenServer that the signs use to add their messages to.
Separately, there are a number of `PaEss.HttpUpdater` GenServers that pull from the queue to send
the messages. The number of updaters and the frequency with which they pull from the queue is
fixed, in order to rate limit the requests to the head end server. The size of the MessageQueue is
fixed to allow some buffering for hiccups in the network, while not being so large that very out
of date messages end up getting sent to ARINC. The ARINC head-end server has a lot of cores, but
is somewhat slow per-core, so we ended up with a largish number of updaters, each posting somewhat
slowly.

![Realtime Signs process diagram](/realtime_signs_processes.png)

## Code organization

The various "engines" which keep track of state are named `Engine.*`.

The main sign module is `Signs.Realtime` which is the GenServer responsible for keeping track of
what's on a sign's two lines and when to play various audio announcements.

Ultimately, the point of the app is to display text content on signs, and play equivalent audio.
This is represented in the app via `Content`. Every kind of text that can be put onto the signs
has a corresponding `Content.Message.*` struct which can be converted into a corresponding
`Content.Audio.*` struct. Both of these can be "serialized" by the app into requests to ARINC.

Important utility modules related to the normal flow of the app are:

- `Signs.Utilities.Messages`: takes a sign and its configuration, and figures out via the engines,
  what _should_ be on the sign right now, returning two `Content.Message.*`s (one for each line).
- `Signs.Utilities.Updater`: takes the current state of the sign, those two aforementioned
  messages about what _should_ be on the sign, and decides if it needs to update either or both of
  the sign's lines.
- `Signs.Utilities.Audio`: decides whether the message changes from the previous step warrant an
  audio announcement, and if so, what exactly the sign should say (how to convert
  `Content.Message.*`s to `Content.Audio.*`s)
