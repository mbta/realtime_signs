Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(objects: :ordered_objects)

source_key = fn s ->
  if s[:stop_id] == "64000" && s[:route_id] in ["15", "23", "28", "44", "45"] && s[:direction_id] == 1 ||
     s[:route_id] in ["741", "742", "743", "746"] && s[:direction_id] == 1 do
    nil
  else
    {s[:route_id], s[:direction_id]}
  end
end

transform_sources = fn sign, key, ckey ->
  if sign[key] do
    val =
      for source <- sign[key], route <- source["routes"] do
        Jason.OrderedObject.new([stop_id: source["stop_id"], route_id: route["route_id"], direction_id: route["direction_id"]])
      end
      |> Enum.group_by(source_key)
      |> Enum.map(fn {_, v} ->
        Jason.OrderedObject.new([sources: v])
      end)
    Enum.map(sign, fn {k, v} ->
      if k == key, do: {ckey, val}, else: {k, v}
    end)
    |> Jason.OrderedObject.new()
  else
    sign
  end
end

signs_json = Enum.map(signs, fn sign ->
  if sign["type"] == "bus" do
    sign
    |> transform_sources.("sources", "configs")
    |> transform_sources.("top_sources", "top_configs")
    |> transform_sources.("bottom_sources", "bottom_configs")
    |> transform_sources.("extra_audio_sources", "extra_audio_configs")
  else
    sign
  end
end)
|> Jason.encode!(pretty: true)

File.write!("priv/signs.json", signs_json <> "\n")
