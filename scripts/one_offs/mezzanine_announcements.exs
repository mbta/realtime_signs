Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms, objects: :ordered_objects)

new_signs =
  for sign <- signs do
    if is_list(sign[:source_config]) do
      sign
      |> put_in([:source_config, Access.all(), :sources, Access.all(), :announce_arriving], false)
      |> put_in([:source_config, Access.all(), :sources, Access.all(), :announce_boarding], false)
    else
      sign
    end
  end

File.write!("priv/signs.json", Jason.encode!(new_signs, pretty: true) <> "\n")
