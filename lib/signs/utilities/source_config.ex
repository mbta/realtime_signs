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

  A sign's data is provided via the "source_config" key. For platform signs, this will be an
  object as defined below. For mezzanine signs, this will be a list of two of these objects,
  which will cause each line to display separately using the corresponding config.

  * headway_group: This determines which headway group to look up when getting headyway time
    ranges, and must match the values set by signs-ui. Most mezzanine signs show both directions
    of the same headway group, and so will have the same value for both configs. A notable
    exception is Ashmont, which handles both the Ashmont and Mattapan headway groups.
  * headway_direction_name: The headsign used to generate the "trains every X minutes" message in
    headway mode. Must be a value recognized by `PaEss.Utilities.headsign_to_destination/1`.
  * sources: A list of source objects (see below for details). The sources determine which
    predictions to use in the `Engine.Predictions` process. When a list of multiple sources is
    provided, their corresponding predictions are aggregated and sorted by arrival time (or
    departure, for terminals), so that the "next" train will be the earliest arriving train from
    any of the sources. For example, the JFK mezzanine sign's top line uses a source list of two
    sources, with GTFS stop IDs 70086 and 70096, which are the Ashmont and Braintree northbound
    platforms. That way the sign will say when the next northbound train will be arriving at JFK,
    from either of the Braintree or Ashmont branches.

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
    :direction_id,
    :routes,
    :platform,
    :terminal?,
    :announce_arriving?,
    :announce_boarding?
  ]
  defstruct @enforce_keys ++
              [:headway_stop_id, multi_berth?: false]

  @type source :: %__MODULE__{
          stop_id: String.t(),
          headway_stop_id: String.t() | nil,
          direction_id: 0 | 1,
          routes: [String.t()] | nil,
          platform: Content.platform() | nil,
          terminal?: boolean(),
          announce_arriving?: boolean(),
          announce_boarding?: boolean(),
          multi_berth?: boolean()
        }

  @type config :: %{
          headway_group: String.t(),
          headway_destination: PaEss.destination() | nil,
          sources: [source()]
        }

  @spec parse!(map() | [map()]) :: config() | {config(), config()}
  def parse!(%{
        "headway_group" => headway_group,
        "headway_direction_name" => headway_direction_name,
        "sources" => sources
      }) do
    {:ok, headway_destination} = PaEss.Utilities.headsign_to_destination(headway_direction_name)

    %{
      headway_group: headway_group,
      headway_destination: headway_destination,
      sources: Enum.map(sources, &parse_source!/1)
    }
  end

  def parse!([top, bottom]) do
    {parse!(top), parse!(bottom)}
  end

  defp parse_source!(
         %{
           "stop_id" => stop_id,
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

    %__MODULE__{
      stop_id: stop_id,
      direction_id: direction_id,
      routes: source["routes"],
      platform: platform,
      terminal?: terminal?,
      announce_arriving?: announce_arriving?,
      announce_boarding?: announce_boarding?,
      multi_berth?: multi_berth?
    }
  end

  @spec multi_source?(config() | {config(), config()}) :: boolean()
  def multi_source?({_, _}), do: true
  def multi_source?(_), do: false

  @spec sign_stop_ids(config() | {config(), config()}) :: [String.t()]
  def sign_stop_ids({top, bottom}) do
    sign_stop_ids(top) ++ sign_stop_ids(bottom)
  end

  def sign_stop_ids(%{sources: sources}) do
    Enum.map(sources, & &1.stop_id)
  end

  @spec sign_routes(config() | {config(), config()}) :: [String.t()]
  def sign_routes({top, bottom}) do
    sign_routes(top) ++ sign_routes(bottom)
  end

  def sign_routes(%{sources: sources}) do
    Enum.flat_map(sources, &(&1.routes || []))
  end

  def get_source_by_stop_and_direction(
        {%{sources: top_source_list}, %{sources: bottom_source_list}},
        stop_id,
        direction_id
      ) do
    get_source_by_stop_and_direction(top_source_list, stop_id, direction_id) ||
      get_source_by_stop_and_direction(bottom_source_list, stop_id, direction_id)
  end

  def get_source_by_stop_and_direction(%{sources: source_list}, stop_id, direction_id) do
    get_source_by_stop_and_direction(source_list, stop_id, direction_id)
  end

  def get_source_by_stop_and_direction(source_list, stop_id, direction_id) do
    Enum.find(
      source_list,
      &(&1.stop_id == stop_id and &1.direction_id == direction_id)
    )
  end
end
