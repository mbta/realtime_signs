Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms, objects: :ordered_objects)

sign_filter = Access.filter(&(&1[:type] == "realtime"))

signs
# Rename source_config and convert to list
|> update_in([sign_filter], fn sign ->
  Enum.map(sign, fn
    {:source_config, v} -> {:configs, List.wrap(v)}
    {k, v} -> {k, v}
  end)
  |> Jason.OrderedObject.new()
end)
# Move announce_arriving and announce_boarding to config level
|> update_in([sign_filter, :configs, Access.all()], fn config ->
  Enum.flat_map(config, fn
    {:sources, sources} ->
      {announce_arrivings, sources} = pop_in(sources, [Access.all(), :announce_arriving])
      {announce_boardings, sources} = pop_in(sources, [Access.all(), :announce_boarding])

      [
        announce_arriving: hd(announce_arrivings),
        announce_boarding: hd(announce_boardings),
        sources: sources
      ]

    {k, v} ->
      [{k, v}]
  end)
  |> Jason.OrderedObject.new()
end)
# Split sources into single route_id
|> update_in([sign_filter, :configs, Access.all(), :sources], fn sources ->
  Enum.flat_map(sources, fn source ->
    Enum.map(source[:routes], fn route_id ->
      Jason.OrderedObject.new(
        stop_id: source[:stop_id],
        route_id: route_id,
        direction_id: source[:direction_id]
      )
    end)
  end)
end)
# Split multi-route configs for platform signs
|> update_in([sign_filter, :configs], fn configs ->
  if Enum.map(configs, &{&1[:headway_group], &1[:headway_direction_name]})
     |> Enum.uniq()
     |> length() == 1 do
    Enum.flat_map(configs, fn config ->
      Enum.group_by(config[:sources], & &1[:route_id])
      |> Enum.map(fn {_, sources} -> put_in(config, [:sources], sources) end)
    end)
  else
    configs
  end
end)
# Add destination field
|> update_in([sign_filter, :configs, Access.all()], fn config ->
  destination =
    case Enum.map(config[:sources], &{&1[:route_id], &1[:direction_id]}) |> Enum.uniq() do
      [{"Green-B", 0}] -> "Boston College"
      [{"Green-B", 1}] -> "Government Center"
      [{"Green-C", 0}] -> "Cleveland Circle"
      [{"Green-C", 1}] -> "Government Center"
      [{"Green-D", 0}] -> "Riverside"
      [{"Green-D", 1}] -> "Union Square"
      [{"Green-E", 0}] -> "Heath Street"
      [{"Green-E", 1}] -> "Medford/Tufts"
      _ -> config[:headway_direction_name]
    end

  Enum.flat_map(config, fn
    {:headway_direction_name, v} -> [headway_direction_name: v, destination: destination]
    {k, v} -> [{k, v}]
  end)
  |> Jason.OrderedObject.new()
end)
|> Jason.encode!(pretty: true)
|> then(&File.write!("priv/signs.json", &1 <> "\n"))
