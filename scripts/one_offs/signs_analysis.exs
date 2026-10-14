Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms)

case System.argv() do
  # Configs that have atypical announcement settings
  ["announcements"] ->
    for %{type: "realtime", configs: configs} <- signs,
        config <- configs,
        config.announce_arriving == config.terminal or
          config.announce_boarding != config.terminal do
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
