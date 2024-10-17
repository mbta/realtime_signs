Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms, objects: :ordered_objects)

transform_config = fn config ->
  Enum.flat_map(config, fn
    {:sources, sources} ->
      [terminal] = Enum.map(sources, & &1[:terminal]) |> Enum.uniq()

      sources =
        Enum.map(sources, fn source ->
          Enum.reject(source, &match?({:terminal, _}, &1)) |> Jason.OrderedObject.new()
        end)

      [{:terminal, terminal}, {:sources, sources}]

    x ->
      [x]
  end)
  |> Jason.OrderedObject.new()
end

signs_json =
  update_in(signs, [Access.filter(&(&1[:type] == "realtime")), :source_config], fn
    [top, bottom] -> [transform_config.(top), transform_config.(bottom)]
    config -> transform_config.(config)
  end)
  |> Jason.encode!(pretty: true)

File.write!("priv/signs.json", signs_json <> "\n")
