Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms, objects: :ordered_objects)

transform_config = fn config ->
  Enum.map(config, fn
    {:sources, sources} ->
      {:sources,
       Enum.map(sources, fn source ->
         Enum.reject(source, &match?({:platform, _}, &1)) |> Jason.OrderedObject.new()
       end)}

    x ->
      x
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
