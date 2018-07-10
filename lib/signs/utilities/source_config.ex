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
  show up on the lines of the sign. If two lists are provided, then the next one trip from each list will
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
  defstruct @enforce_keys

  @type one :: %__MODULE__{
    stop_id: String.t(),
    direction_id: 0 | 1,
    platform: :ashmont | :braintree | nil,
    terminal?: boolean(),
    announce_arriving?: boolean(),
  }

  @type full :: {[one()]} | {[one()], [one()]}

  @spec parse!([[map()]]) :: full()
  def parse!([both_lines_config]) do
    { Enum.map(both_lines_config, &parse_one!/1) }
  end
  def parse!([top_line_config, bottom_line_config]) do
    {
      Enum.map(top_line_config, &parse_one!/1),
      Enum.map(bottom_line_config, &parse_one!/1),
    }
  end

  defp parse_one!(%{"stop_id" => stop_id, "direction_id" => direction_id, "platform" => platform, "terminal" => terminal?, "announce_arriving" => announce_arriving?}) do
    platform = case platform do
      nil -> nil
      "ashmont" -> :ashmont
      "braintree" -> :braintree
    end

    %__MODULE__{
      stop_id: stop_id,
      direction_id: direction_id,
      platform: platform,
      terminal?: terminal?,
      announce_arriving?: announce_arriving?,
    }
  end
end
