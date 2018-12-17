defmodule Signs.Utilities.SourceConfig do
  @moduledoc """
  Configuration for a sign's data sourcess, via JSON.

  Provide each individual data source as a JSON map like the following:

  {
    "stop_id": "123",
    "direction_id": 0,
    "platform": null,
    "terminal": true
  }

  where "stop_id" is the GTFS Stop ID, "direction_id" is either 0 or 1 and corresponds to north/south,
  east/west, inbound/outbound, platform is "ashmont", "braintree" (for JFK/UMass weirdness) or null, and
  "terminal" is whether the stop is considered a terminal (whether we should use the arrival or departure
  prediction times, and whether we should announce "arrives" or "departs" on the speakers).

  A list of sources can be provided in a group: [{...}, {...}, {...}, ...]. All the sources will be sorted
  together in order of their respective arrivals/departures (depending on their respective "terminal" values).
  For example, JFK mezzanine northbound uses 70086 and 70096 in a source group, since those are the Ashmont
  and Braintree platforms, and it wishes to display the next train from either location.

  We currently support up to two _lists_ of sources. If one list is provided, then its next two trips will
  show up on the lines of the sign. If two lists are provided, then the next trip from each list will
  appear on different lines of the sign.

  The JSON structure for one list of sources is:

  [
    [{...}, {...}]
  ]

  While the JSON structure for two lists of sources is:

  [
    [{...}, {...}],
    [{...}, {...}]
  ]
  """

  @enforce_keys [:stop_id, :direction_id, :platform, :terminal?, :announce_arriving?]
  defstruct @enforce_keys ++ [:routes, multi_berth?: false]

  @type source :: %__MODULE__{
          stop_id: String.t(),
          headway_direction_name: String.t(),
          direction_id: 0 | 1,
          routes: [String.t()] | nil,
          platform: :ashmont | :braintree | nil,
          terminal?: boolean(),
          announce_arriving?: boolean(),
          multi_berth?: boolean()
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
           "announce_arriving" => announce_arriving?
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
      headway_direction_name: headway_direction_name,
      direction_id: direction_id,
      routes: source["routes"],
      platform: platform,
      terminal?: terminal?,
      announce_arriving?: announce_arriving?,
      multi_berth?: multi_berth?
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
end
