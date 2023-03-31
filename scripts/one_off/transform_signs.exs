Mix.install([{:jason, "~> 1.4.0"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(objects: :ordered_objects)

signs_json = Enum.map(signs, fn sign ->
  {headway_group, sign} = pop_in(sign["headway_group"])
  headway_groups = case headway_group do
    [one, two] -> [one, two]
    one -> [one, one]
  end
  make_config = fn {list, headway_group} ->
    Jason.OrderedObject.new([
      headway_group: headway_group,
      headway_direction_name:
        case Enum.map(list, fn s -> s["headway_direction_name"] end) |> Enum.uniq() do
          [name] -> name
          _ -> nil
        end,
      sources: Enum.map(list, fn source ->
        {_, source} = pop_in(source["headway_direction_name"])
        {_, source} = pop_in(source["source_for_headway"])
        source
      end)
    ])
  end
  update_in(sign["source_config"], fn source_config ->
    case source_config do
      [one] -> make_config.({one, hd(headway_groups)})
      [one, two] -> Enum.zip([one, two], headway_groups) |> Enum.map(make_config)
    end
  end)
end)
|> Jason.encode!(pretty: true)

File.write!("priv/signs.json", signs_json)
