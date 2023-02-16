# This is a temporary script to help port Transitway Engine functionality. It parses the
# code/config and transforms the data into a format that works for realtime_signs.

# This script currently expects to be run from the root directory of realtime_signs,
# with a copy of transitway_engine sitting in a sibling directory.

# NOTE: This script will modify/overwrite files, so only run it with a clean working directory.

Mix.install([{:jason, "~> 1.4.0"}])

lines =
  File.read!("../transitway_engine/config/transitwayRoutes.cfg")
  |> String.split("\n")
  |> Enum.filter(&String.match?(&1, ~r/^[^#]/))

{[_ | station_lines], lines} = Enum.split_while(lines, &(&1 != "[Route takes]"))

{[_ | route_lines], [_ | abbrev_lines]} =
  Enum.split_while(lines, &(&1 != "[Visual destination strings]"))

lines =
  File.read!("../transitway_engine/View/view_SignageLogic.c")
  |> String.split("\r\n")
  |> Enum.filter(&(!String.match?(&1, ~r/^\s*$/) && !String.match?(&1, ~r/^\s*\/\//)))

[_, _ | lines] = Enum.drop_while(lines, &(&1 != "int view_InitializeSignageLogic()"))
{initialize_lines, _lines} = Enum.split_while(lines, &(&1 != "  if (view_processRoutesFile())"))
# TODO continue parsing audio zones

routes_lookup =
  for line <- station_lines,
      into: %{} do
    [id | source_strings] = String.split(line, ",")

    routes =
      for str <- source_strings do
        [route_id, direction_id] = String.split(str, "_")
        Jason.OrderedObject.new(route_id: route_id, direction_id: String.to_integer(direction_id))
      end

    {id, routes}
  end

_route_takes =
  for line <- route_lines do
    [name, number] = String.split(line, ",")
    %{name: name, number: String.to_integer(number)}
  end

# |> IO.inspect

abbreviations_code =
  for [line1, line2] <- Enum.chunk_every(abbrev_lines, 2) do
    [headsign, _] = String.split(line1, ",")

    abbreviations =
      for abbrev <- String.split(line2, ",") do
        String.trim(abbrev)
      end
      |> Enum.uniq()

    %{headsign: headsign, abbreviations: abbreviations}
  end
  |> Enum.map(fn %{headsign: headsign, abbreviations: abbreviations} ->
    "    {#{inspect(headsign)}, #{inspect(abbreviations)}}"
  end)
  |> Enum.concat(["    {\"Silver Line Way\", [\"Slvr Ln Way\"]}"])
  |> Enum.join(",\n")
  |> (fn lines ->
        "  @headsign_abbreviation_mappings [\n" <> lines <> "\n  ]"
      end).()

signs_json =
  for [line1, line2] <- Enum.chunk_every(initialize_lines, 2) do
    [_, id, pa_ess_loc, text_zone, audio_zones, stop_id, _max_preds, max_minutes] =
      Regex.run(
        ~r/  InitializeStop\([^,]+, "([\w.]+)", "(\w+)", '(\w)', "(\d*)", ([^,]+), +(\d), (\d+)\)/,
        line1 <> " " <> String.trim(line2)
      )

    Jason.OrderedObject.new(
      [
        id: id,
        pa_ess_loc: pa_ess_loc,
        text_zone: text_zone,
        audio_zones:
          for {c, i} <- Enum.with_index(["m", "c", "n", "s", "e", "w"]),
              String.at(audio_zones, i) == "1" do
            c
          end,
        type: "bus"
      ] ++
        if id == "Silver_Line.World_Trade_Ctr_mezz" do
          top_routes = Map.fetch!(routes_lookup, "Silver_Line.World_Trade_Ctr_WB")
          bottom_routes = Map.fetch!(routes_lookup, "Silver_Line.World_Trade_Ctr_EB")

          [
            top_sources: [Jason.OrderedObject.new(stop_id: "74615", routes: top_routes)],
            bottom_sources: [Jason.OrderedObject.new(stop_id: "74613", routes: bottom_routes)]
          ]
        else
          [_, sid] = Regex.run(~r/STOP_ID_(\d+)_/, stop_id)
          routes = Map.fetch!(routes_lookup, id)
          [sources: [Jason.OrderedObject.new(stop_id: sid, routes: routes)]]
        end ++
        if Enum.any?(["Eastern_Ave", "Box_District", "Bellingham_Square", "Chelsea"], &String.contains?(id, &1)) do
          [chelsea_bridge: true]
        else
          []
        end ++
        [
          max_minutes: String.to_integer(max_minutes)
        ]
    )
  end
  |> Jason.encode!()
  |> Jason.Formatter.pretty_print()

case System.argv() do
  ["signs"] -> File.write!("priv/bus-signs.json", signs_json)
  ["abbreviations"] -> File.write!("priv/abbreviations.ex", abbreviations_code)
  _ -> IO.puts("ERROR: specify a command")
end
