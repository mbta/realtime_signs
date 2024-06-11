# Modifies signs.json with SCU ids

Mix.install([
  {:csv, "~> 3.2"},
  {:jason, "~> 1.4.0"}
])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms, objects: :ordered_objects)

data =
  File.stream!("scu.tsv")
  |> CSV.decode!(separator: ?\t)
  |> Map.new(&List.to_tuple/1)

signs_json =
  Enum.map(signs, fn sign ->
    Enum.flat_map(sign, fn
      {:pa_ess_loc, v} -> [{:pa_ess_loc, v}, {:scu_id, Map.get(data, v)}]
      x -> [x]
    end)
    |> Jason.OrderedObject.new()
  end)
  |> Jason.encode!(pretty: true)

File.write!("priv/signs.json", signs_json <> "\n")
