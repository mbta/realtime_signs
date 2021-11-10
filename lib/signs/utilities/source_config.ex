defmodule Signs.Utilities.SourceConfig do
  @moduledoc """
  Configuration for a sign's data sourcess, via JSON. Configuration of a sign looks like:

  ## Sign (zone) config

  {
    "id": "roxbury_crossing_southbound",
    "headway_group": "orange_trunk",
    "type": "realtime",
    "pa_ess_loc": "OROX",
    "text_zone": "s",
    "audio_zones": ["s"],
    "read_loop_offset": 60,
    "source_config": [...]
  },

  * id: the internal ID of this "sign". Really, it's a "zone" and could have a few physical signs
    as a part of it in the station, but they all display exactly the same content. Logically
    they're a single entity in the ARINC system as far as we can interact with it. This ID is also
    used by signs-ui, and is how realtime-signs knows how signs-ui has configured the sign.
  * headway_group: this references the signs-ui values that the PIOs set for headways.
  * type: always "realtime". (there were other types in previous iterations of the app.)
  * pa_ess_loc: the ARINC station code. Starts with the line color B, R, O, G, or M, and then
    three letters for the station.
  * text_zone: one of the 6 zones ARINC divides a station into, for the purpose of sending text to
    the sign.
  * audio_zones: a list of those ARINC zones for the purpose of sending audio. This may differ
    from the text_zone when the speakers are close enough to cause confusion. For example, at Park
    Street for the Red line, we have the center platform text_zone set to "c", but the audio_zones
    set to [], while the north zone we have the text_zone set to "n" and the audio_zones set to
    ["n", "c"]. So the center platform doesn't play audio of its *own*, but rather the north and
    south platforms play their audio over the center platform speakers. Since a train that goes to
    "ARR" will do so simultaneously for either the north or south platform *and* the center
    platform, this configuration prevents simultaneous, slightly overlapping audio of the same
    content.
  * read_loop_offset: how many seconds to wait after app start-up before entering the "read loop",
    which reads things like "The next train to X arrives in 3 minutes. The following train arrives
    in 8 minutes". We generally have different read_loop_offsets for different zones, or where
    speakers are particularly close, to encourage them to play their audio at different times.
  * source_config: see below.

  ## Source config
  A sign's data is provided via the "source_config" key, which is a list of lists of "sources"
  (see next section).

  A list of sources can be provided: [{...}, {...}, {...}, ...]. The sources determine which
  predictions to use in the `Engine.Predictions` process. When a list of multiple sources is
  provided, their corresponding predictions are aggregated and sorted by arrival time (or
  departure, for terminals), so that the "next" train will be the earliest arriving train from any
  of the sources. For example, the JFK mezzanine sign's top line uses a source list of two
  sources, with GTFS stop IDs 70086 and 70096, which are the Ashmont and Braintree northbound
  platforms. That way the sign will say when the next northbound train will be arriving at JFK,
  from either of the Braintree or Ashmont branches.

  The "source_config" key currently supports up to two _lists_ of sources. If one list is
  provided, then this sign is a "platform" sign and its next two trips will show up on the two
  lines of the sign. If two lists are provided, then this sign is a "mezzanine" or "center" sign
  and the next trip from each list will appear on different lines of the sign.

  The JSON structure for one list of sources is:

  [
    [{...}, {...}]
  ]

  While the JSON structure for two lists of sources is:

  [
    [{...}, {...}],
    [{...}, {...}]
  ]

  ## Source

  Allows specifying one of a sign's data sources that it uses to calculate what to display. It
  looks like:

  {
    "stop_id": "70008",
    "routes": ["Orange"],
    "direction_id": 0,
    "headway_direction_name": "Forest Hills",
    "platform": null,
    "terminal": false,
    "announce_arriving": true,
    "announce_boarding": false
  }

  * stop_id: The GTFS stop_id that it uses for prediction data.
  * routes: A list of routes that are relevant to this sign regarding alerts.
  * direction_id: 0 or 1, used in tandem with the stop ID for predictions
  * headway_direction_name: The headsign used to generate the "trains every X minutes" message in
    headway mode. Must be a value recognized by `PaEss.Utilities.headsign_to_destination/1`.
  * platform: mostly null, but :ashmont | :braintree for JFK/UMass, where it's used for the "next
    train to X is approaching, on the Y platform" audio.
  * terminal: whether this is a "terminal", and should use arrival or departure times in its
    countdown.
  * announce_arriving: whether to play audio when a sign goes to ARR.
  * announce_boarding: whether to play audio when a sign goes to BRD. Generally we do one or the
    other. Considerations include how noisy the station is, what we've done in the past, how
    reliable ARR is (BRD is reliable, but especially at Boylston, e.g., ARR can have the "next"
    train change frequently, so you don't want to announce the wrong one is arriving), and whether
    it's a terminal or not.
  """

  require Logger

  @enforce_keys [
    :stop_id,
    :headway_destination,
    :direction_id,
    :platform,
    :terminal?,
    :announce_arriving?,
    :announce_boarding?
  ]
  defstruct @enforce_keys ++
              [:routes, :headway_stop_id, multi_berth?: false, source_for_headway?: false]

  @type source :: %__MODULE__{
          stop_id: String.t(),
          headway_stop_id: String.t() | nil,
          headway_destination: PaEss.destination(),
          direction_id: 0 | 1,
          routes: [String.t()] | nil,
          platform: Content.platform() | nil,
          terminal?: boolean(),
          announce_arriving?: boolean(),
          announce_boarding?: boolean(),
          multi_berth?: boolean(),
          source_for_headway?: boolean()
        }

  @type config :: {[source()]} | {[source()], [source()]}

  @spec parse!([[map()]]) :: config()
  def parse!([both_lines_config]) do
    {Enum.map(both_lines_config, &parse_source!/1)}
  end

  def parse!([top_line_config, bottom_line_config]) do
    {
      Enum.map(top_line_config, &parse_source!/1),
      Enum.map(bottom_line_config, &parse_source!/1)
    }
  end

  defp parse_source!(
         %{
           "stop_id" => stop_id,
           "headway_direction_name" => headway_direction_name,
           "direction_id" => direction_id,
           "platform" => platform,
           "terminal" => terminal?,
           "announce_arriving" => announce_arriving?,
           "announce_boarding" => announce_boarding?
         } = source
       ) do
    platform =
      case platform do
        nil -> nil
        "ashmont" -> :ashmont
        "braintree" -> :braintree
      end

    multi_berth? =
      case source["multi_berth"] do
        true -> true
        _ -> false
      end

    source_for_headway? =
      case source["source_for_headway"] do
        true -> true
        _ -> false
      end

    {:ok, headway_destination} = PaEss.Utilities.headsign_to_destination(headway_direction_name)

    %__MODULE__{
      stop_id: stop_id,
      headway_destination: headway_destination,
      direction_id: direction_id,
      routes: source["routes"],
      platform: platform,
      terminal?: terminal?,
      announce_arriving?: announce_arriving?,
      announce_boarding?: announce_boarding?,
      multi_berth?: multi_berth?,
      source_for_headway?: source_for_headway?
    }
  end

  @spec multi_source?(config) :: boolean()
  def multi_source?({_, _}), do: true
  def multi_source?({_}), do: false

  @spec sign_stop_ids(config) :: [String.t()]
  def sign_stop_ids({s1, s2}) do
    Enum.map(s1, & &1.stop_id) ++ Enum.map(s2, & &1.stop_id)
  end

  def sign_stop_ids({s}) do
    Enum.map(s, & &1.stop_id)
  end

  @spec sign_routes(config) :: [String.t()]
  def sign_routes({s1, s2}) do
    Enum.flat_map(s1, &(&1.routes || [])) ++ Enum.flat_map(s2, &(&1.routes || []))
  end

  def sign_routes({s}) do
    Enum.flat_map(s, &(&1.routes || []))
  end
end
