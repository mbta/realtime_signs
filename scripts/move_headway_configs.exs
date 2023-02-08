Mix.install([{:jason, "~> 1.4.0"}])

parse_source = fn (sign, source_config) ->
  Enum.map(source_config, fn source_list ->
    Enum.map(source_list, fn source ->
        Jason.OrderedObject.new(
          stop_id: source["stop_id"],
          routes: source["routes"],
          direction_id: source["direction_id"],
          headway_direction_name: source["headway_direction_name"],
          headway_group: sign["headway_group"],
          platform: source["platform"],
          terminal: source["terminal"],
          announce_arriving: source["announce_arriving"],
          announce_boarding: source["announce_boarding"]
        )
      end)
    end)
  end

updated_config =
  File.read!("../priv/signs.json")
  |> Jason.decode!()
  |> Enum.map(
    fn %{"source_config" => source_config} = sign ->
      sign
      |> Map.put("source_config", parse_source.(sign, source_config))
      |> then(fn sign ->
        Jason.OrderedObject.new(
          id: sign["id"],
          type: sign["type"],
          pa_ess_loc: sign["pa_ess_loc"],
          read_loop_offset: sign["read_loop_offset"],
          text_zone: sign["text_zone"],
          audio_zones: sign["audio_zones"],
          source_config: sign["source_config"]
        )
      end)
    end)
  |> Jason.encode!()
  |> Jason.Formatter.pretty_print()

  File.write!("new_configs.json", updated_config)
