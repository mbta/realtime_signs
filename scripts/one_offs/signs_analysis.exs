Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms)

case System.argv() do
  # Configs that have atypical announcement settings
  ["announcements"] ->
    for %{source_config: source_config} <- signs,
        config <- List.wrap(source_config),
        [announce_arriving?] = Enum.map(config.sources, & &1.announce_arriving) |> Enum.uniq(),
        [announce_boarding?] = Enum.map(config.sources, & &1.announce_boarding) |> Enum.uniq(),
        announce_arriving? == config.terminal or announce_boarding? != config.terminal do
      config
    end
    |> IO.inspect(limit: :infinity)

  # Signs with mismatched text/audio zones
  ["zones"] ->
    for %{text_zone: text_zone, audio_zones: audio_zones} = sign <- signs,
        [text_zone] != audio_zones do
      [id: sign.id, text: [text_zone], audio: audio_zones]
    end
    |> IO.inspect(limit: :infinity)
end
