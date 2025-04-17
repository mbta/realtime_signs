# Architecture

This document describes the high-level architecture of Realtime Signs (RTS). The goal of this document
is to provide a useful orientation to a new contributor to the codebase.

## Application description

RTS is a core part of the larger PA/ESS (Public Address and Electronic Signage System) and is the app that drives subway and bus countdown predictions and announcements on the countdown signs and speakers in and around stations. It does this by continually downloading data from multiple sources (primarily GTFS-rt and V3 API), applying some transformations and logic, and sending commands to the servers in each station that tell the signs what to display or the speakers to play at any given time.

## Architecture overview

The core of the application is the `Signs.Realtime` GenServer which typically represents a subgroup of physical signs and speakers that RTS sends content to. There is also the bus equivalent `Signs.Bus` GenServer which fills the same role but currently uses different logic for historical reasons. Within the context of RTS and the broader PA/ESS, we often refer to each of these subgroups as a single "sign" for simplicity. Each of these conceptual signs is defined at start-up and configured via `priv/signs.json`. See `Signs.Utilities.SourceConfig` for documentation of the format of the `signs.json` file.

These sign processes are independent and run a roughly 1 second loop during which it will fetch various bits of data (alerts, predictions, signs-ui configuration, static schedules, etc.), typically from dedicated "Engine" processes which are responsible for managing local state containing this data. The sign process will then calculate what content should be displayed on its configured signs and/or what audio should be read out/triggered on its speakers. Additionally, these processes maintain small bits of state to help manage when content should be updated.

Once the desired content has been rendered, the `Signs.Realtime` or `Signs.Bus` process will add it as messages to a queue (via `PaEss.Updater`) which will be polled by a pool of processes dedicated to encoding content as HTTP requests and sending them to the servers located in each station, often referred to as SCUs (Station Control Units).

## Code organization

### Engines
Found in the `lib/engine` directory, the "Engine" processes are responsible for keeping track of state to be used by other processes. Some of the key Engines and what they maintain are listed below:
- [`Engine.Alerts`](/lib/engine/alerts.ex) - alerts data from the V3 API
- [`Engine.BusPredictions`](/lib/engine/bus_predictions.ex) - bus predictions from the V3 API
- [`Engine.Config`](/lib/engine/config.ex) - pieces of dynamic config such as sign mode (auto, static text, off, etc.), SCU migration status, configured headway values, etc.
- [`Engine.Locations`](/lib/engine/locations.ex) - realtime vehicle location data from the GTFS-rt enhanced feed
- [`Engine.PaMessages`](/lib/engine/pa_messages.ex) fetches active PA Messages from Screenplay and determines when to play them in stations
- [`Engine.Predictions`](/lib/engine/predictions.ex) light and heavy rail predictions from the GTFS-rt enhanced feed

### Content
The different categories of content that we show/play in stations are encoded as top-level structs in the [`lib/message`](/lib/message/) directory. Each of these structs must implement the `Message` protocol in order for the code to know how to render said content in various visual forms (single-line, full-page, multi-line). These implementations are called in the centralized rendering logic in `Signs.Utilities.Messages` to make sure that all of the desired content fits appropriately within the available space. See `get_messages` in `Signs.Utilities.Messages` to understand how different message types are prioritized.

The `Message` protocol also has a callback called `to_audio/2` that defines how a given Message type can be translated to a corresponding audio struct or list of audio structs. These audio structs are found in the [`lib/content/audio`](/lib/content/audio/) directory and implement their own protocol called `Content.Audio` which informs the centralized audio logic in `Signs.Utilities.Audio` how to render the audio struct either as a list of ids that map to pre-rendered audio files (legacy) or as a string to be used for text-to-speech generation (migrated).

### Utilities

There is a set of utility modules that contain shared logic and are key to understanding RTS
- [`Content.Utilities`](/lib/content/utilities.ex) - helpers for formatting, interpreting, and translating transit data into meaningful content
- [`PaEss.Utilities`](/lib/pa_ess/utilities.ex) - helpers for translating data into standardized strings and audio clips
- [`Signs.Utilities.Audio`](/lib/signs/utilities/audio.ex) - handles converting `Message` structs to audio `Content.Audio` structs and rendering audio before it is enqueued
- [`Signs.Utilities.Messages`](/lib/signs/utilities/messages.ex) - encapsulates the core logic for determing what content to display on a sign and how to display it
- [`Signs.Utilities.SignsConfig`](/lib/signs/utilities/signs_config.ex) + [`Signs.Utilities.SourceConfig`](/lib/signs/utilities/source_config.ex) - helpers for parsing and accessing data from `signs.json`

