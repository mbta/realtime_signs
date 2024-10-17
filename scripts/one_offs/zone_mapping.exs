Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms)

for %{text_zone: text_zone, audio_zones: audio_zones} = sign <- signs,
    [text_zone] != audio_zones do
  [id: sign.id, text: [text_zone], audio: audio_zones]
end
|> IO.inspect()

for %{source_config: source_config} <- signs,
    config <- List.wrap(source_config) do
  Enum.map(config.sources, & &1.announce_boarding)
end
|> Enum.filter(fn list -> length(Enum.uniq(list)) > 1 end)
|> IO.inspect(limit: :infinity)
