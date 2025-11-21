Mix.install([{:jason, "~> 1.4.0"}, {:csv, "~> 3.2"}])

signs =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms)

Enum.map(signs, fn sign ->
  text =
    case sign do
      %{type: "realtime"} = sign ->
        List.wrap(sign.source_config)
        |> Enum.map_join(", ", fn config ->
          line =
            Enum.flat_map(config.sources, & &1.routes)
            |> Enum.uniq()
            |> case do
              ["Green-" <> branch] -> "Green #{branch}"
              [single] -> single
              routes -> "Green #{Enum.map_join(routes, "/", fn "Green-" <> b -> b end)}"
            end

          "#{line} to #{config.headway_direction_name}"
        end)

      %{id: "Silver_Line" <> _} = sign ->
        [sign[:configs], sign[:top_configs], sign[:bottom_configs]]
        |> Enum.filter(fn x -> x end)
        |> Enum.map_join(", ", fn configs ->
          if configs == [] do
            ""
          else
            line =
              for config <- configs, source <- config.sources, uniq: true do
                case source.route_id do
                  "741" -> "SL1"
                  "742" -> "SL2"
                  "743" -> "SL3"
                  "746" -> "SLW"
                end
              end
              |> Enum.join("/")

            "#{line} to #{hd(configs).headway_direction_name}"
          end
        end)

      sign ->
        for config <- sign[:configs], source <- config.sources, uniq: true do
          source.route_id
        end
        |> Enum.join(", ")
    end

  [sign.scu_id, "#{sign.pa_ess_loc}-#{sign.text_zone}", sign.id, text]
end)
|> Enum.sort()
|> CSV.encode()
|> Enum.join()
|> IO.puts()
