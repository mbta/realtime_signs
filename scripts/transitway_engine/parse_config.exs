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
# TODO continue parsing audio zones

routes_list =
  for line <- station_lines do
    [id | source_strings] = String.split(line, ",")

    routes =
      for str <- source_strings do
        [route_id, direction_id] = String.split(str, "_")
        Jason.OrderedObject.new(route_id: route_id, direction_id: String.to_integer(direction_id))
      end

    %{id: id, routes: routes}
  end

for line <- route_lines do
  [name, number] = String.split(line, ",")
  %{name: name, number: String.to_integer(number)}
end

# |> IO.inspect

for [line1, line2] <- Enum.chunk_every(abbrev_lines, 2) do
  [name, number] = String.split(line1, ",")
  abbreviations = String.split(line2, ",")
  %{name: name, number: String.to_integer(number), abbreviations: abbreviations}
end

# |> IO.inspect

signs_json =
  for [line1, line2] <- Enum.chunk_every(initialize_lines, 2) do
    [_, id, pa_ess_loc, text_zone, audio_zones, stop_id, max_preds, max_minutes] =
      Regex.run(
        ~r/  InitializeStop\([^,]+, "([\w.]+)", "(\w+)", '(\w)', "(\d*)", ([^,]+), +(\d), (\d+)\)/,
        line1 <> " " <> String.trim(line2)
      )

    Jason.OrderedObject.new(
      id: id,
      pa_ess_loc: pa_ess_loc,
      text_zone: text_zone,
      audio_zones:
        for {c, i} <- Enum.with_index(["m", "c", "n", "s", "e", "w"]),
            String.at(audio_zones, i) == "1" do
          c
        end,
      type: "bus",
      sources:
        with [_, sid] <- Regex.run(~r/STOP_ID_(\d+)_/, stop_id),
             %{routes: routes} <- Enum.find(routes_list, &match?(%{id: ^id}, &1)) do
          [Jason.OrderedObject.new(stop_id: sid, routes: routes)]
        else
          _ -> []
        end,
      max_preds: String.to_integer(max_preds),
      max_minutes: String.to_integer(max_minutes)
    )
  end
  |> Jason.encode!()
  |> Jason.Formatter.pretty_print()

File.write!("priv/signs.json", signs_json)
