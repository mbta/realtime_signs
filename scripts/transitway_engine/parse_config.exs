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
{initialize_lines, lines} = Enum.split_while(lines, &(&1 != "  if (view_processRoutesFile())"))
[_, _, _, _ | audio_lines] = Enum.take_while(lines, &(&1 != "  return 0; // success"))
# TODO continue parsing audio zones

audio_lookup =
  for [line1, _, line3] <- Enum.chunk_every(audio_lines, 3),
      into: %{} do
    [_, id, offset] = Regex.run(~r/^  \w+.(\w+)_audio\.\w+ = (\d+);/, line1)
    [_, interval] = Regex.run(~r/ = (\d+);/, line3)
    {id, %{interval: String.to_integer(interval), offset: String.to_integer(offset)}}
  end

audio_key = fn id ->
  cond do
    String.starts_with?(id, "Silver_Line.South_Station") ->
      "SouthSta"

    String.starts_with?(id, "Silver_Line.Courthouse") ->
      "Courthouse"

    String.starts_with?(id, "Silver_Line.World_Trade_Ctr") ->
      "WTC"

    String.starts_with?(id, "Silver_Line.Eastern_Ave") ->
      "EasternAve"

    String.starts_with?(id, "Silver_Line.Box_District") ->
      "BoxDistrict"

    String.starts_with?(id, "Silver_Line.Bellingham_Square") ->
      "BellinghamSq"

    String.starts_with?(id, "Silver_Line.Chelsea") ->
      "Chelsea"

    String.starts_with?(id, "bus.Nubian") ->
      [_, letter] = Regex.run(~r/Platform_(\w)/, id)
      "Nubian_#{letter}"

    String.starts_with?(id, "bus.Lechmere") ->
      "Lechmere"

    true ->
      id |> String.replace("bus.", "")
  end
end

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

route_takes_code =
  for line <- route_lines do
    [route, take_id] = String.split(line, ",")
    %{route: route, take_id: String.to_integer(take_id)}
  end
  |> Enum.map(fn %{route: route, take_id: take_id} ->
    "    #{inspect(route)} => #{inspect(to_string(take_id))}"
  end)
  |> Enum.join(",\n")
  |> (fn lines ->
        "  @route_take_lookup %{\n" <> lines <> "\n  }"
      end).()

destinations =
  for [line1, line2] <- Enum.chunk_every(abbrev_lines, 2) do
    [headsign, take_id] = String.split(line1, ",")

    abbreviations =
      for abbrev <- String.split(line2, ",") do
        String.trim(abbrev)
      end
      |> Enum.uniq()

    %{headsign: headsign, take_id: String.to_integer(take_id), abbreviations: abbreviations}
  end

abbreviations_code =
  destinations
  |> Enum.map(fn %{headsign: headsign, abbreviations: abbreviations} ->
    "    {#{inspect(headsign)}, #{inspect(abbreviations)}}"
  end)
  |> Enum.concat([
    "    {\"Silver Line Way\", [\"Slvr Ln Way\"]}",
    "    {\"Drydock\", [\"Drydock\"]}"
  ])
  |> Enum.join(",\n")
  |> (fn lines ->
        "  @headsign_abbreviation_mappings [\n" <> lines <> "\n  ]"
      end).()

headsign_takes_code =
  destinations
  |> Enum.map(fn %{headsign: headsign, take_id: take_id} ->
    "    {#{inspect(headsign)}, #{inspect(to_string(take_id))}}"
  end)
  |> Enum.concat([
    "    {\"Silver Line Way\", \"570\"}",
    "    {\"Drydock\", \"571\"}"
  ])
  |> Enum.join(",\n")
  |> (fn lines ->
        "  @headsign_take_mappings [\n" <> lines <> "\n  ]"
      end).()

signs_json =
  for [line1, line2] <- Enum.chunk_every(initialize_lines, 2) do
    [_, id, pa_ess_loc, text_zone, audio_zones, stop_id, _max_preds, max_minutes] =
      Regex.run(
        ~r/  InitializeStop\([^,]+, "([\w.]+)", "(\w+)", '(\w)', "(\d*)", ([^,]+), +(\d), (\d+)\)/,
        line1 <> " " <> String.trim(line2)
      )

    %{interval: interval, offset: offset} = audio_lookup[audio_key.(id)]

    Jason.OrderedObject.new(
      [
        id: id,
        pa_ess_loc: pa_ess_loc,
        read_loop_interval: interval * 60,
        read_loop_offset: offset * 60,
        text_zone: text_zone,
        audio_zones:
          if id == "bus.Nubian_Platform_E_west" do
            []
          else
            for {c, i} <- Enum.with_index(["m", "c", "n", "s", "e", "w"]),
                String.at(audio_zones, i) == "1" do
              c
            end
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

          [sources: [Jason.OrderedObject.new(stop_id: sid, routes: routes)]] ++
            if id == "bus.Nubian_Platform_E_east" do
              extra_routes = Map.fetch!(routes_lookup, "bus.Nubian_Platform_E_west")

              [
                extra_audio_sources: [
                  Jason.OrderedObject.new(stop_id: "64000", routes: extra_routes)
                ]
              ]
            else
              []
            end
        end ++
        cond do
          Enum.any?(
            ["Eastern_Ave", "Box_District", "Bellingham_Square", "Chelsea"],
            &String.contains?(id, &1)
          ) ->
            [chelsea_bridge: "audio_visual"]

          Enum.any?(
            ["South_Station", "Courthouse", "World_Trade_Ctr"],
            &String.contains?(id, &1)
          ) ->
            [chelsea_bridge: "audio"]

          true ->
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
  ["signs"] ->
    File.write!("priv/bus-signs.json", signs_json)

  ["mappings"] ->
    File.write!(
      "priv/mappings.ex",
      Enum.join([abbreviations_code, headsign_takes_code, route_takes_code], "\n")
    )

  _ ->
    IO.puts("ERROR: specify a command")
end
