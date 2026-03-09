Mix.install([{:jason, "~> 1.4.0"}, {:csv, "~> 3.2"}, {:httpoison, "~> 2.3.0"}])

api_url = System.get_env("API_V3_URL")
api_key = System.get_env("API_V3_KEY")

%{status_code: 200, body: body} =
  HTTPoison.get!(
    api_url <> "/stops",
    [{"x-api-key", api_key}],
    timeout: 10000,
    recv_timeout: 10000,
    params: %{
      "filter[route]" => "Red,Orange,Blue,Green-B,Green-C,Green-D,Green-E,Mattapan"
    }
  )

%{"data" => data} = Jason.decode!(body)

normalize_name = fn name ->
  name
  |> String.replace("Street", "St")
  |> String.replace("Avenue", "Ave")
  |> String.upcase()
  |> String.replace(~r/[^A-Z]/, "")
end

abbrev_lookup =
  File.stream!("../naming.csv")
  |> Stream.drop(1)
  |> CSV.decode!()
  |> Enum.flat_map(fn [_, _, name1, name2, abbrev, _] -> [{name1, abbrev}, {name2, abbrev}] end)
  |> Map.new()
  |> Map.merge(%{
    "Amory Street" => "Amory St",
    "Shawmut" => "Shawmut"
  })
  |> Map.new(fn {name, abbrev} -> {normalize_name.(name), abbrev} end)

id_lookup =
  Map.new(data, fn stop -> {stop["attributes"]["name"], stop["id"]} end)
  |> Map.merge(%{"Chelsea" => "place-chels"})

take_lookup =
  File.stream!("../takes.csv")
  |> Stream.drop(2)
  |> Enum.reverse()
  |> Map.new(fn s ->
    case String.trim(s) |> String.split("   ", parts: 3, trim: true) do
      [id, _, text] -> {String.trim(text), id}
      _ -> {"", nil}
    end
  end)
  |> Map.merge(%{
    "Allston Street" => "4210",
    "Amory Street" => "4211",
    "Babcock Street" => "4212",
    "Back of the Hill" => "4213",
    "Ball Square" => "4214",
    "Blandford Street" => "4215",
    "Boston University Central" => "4216",
    "Boston University East" => "4217",
    "Brandon Hall" => "4218",
    "Chestnut Hill Avenue" => "4219",
    "Chinatown" => "4220",
    "Chiswick Road" => "4221",
    "Coolidge Corner" => "4222",
    "Copley" => "4223",
    "Dean Road" => "4224",
    "East Somerville" => "4225",
    "Englewood Avenue" => "4226",
    "Fairbanks Street" => "4227",
    "Fenwood Road" => "4228",
    "Fields Corner" => "4229",
    "Gilman Square" => "4230",
    "Griggs Street" => "4231",
    "Harvard Avenue" => "4232",
    "Hawes Street" => "4233",
    "Hynes Convention Center" => "4234",
    "Kent Street" => "4235",
    "Longwood Medical Area" => "4236",
    "Magoun Square" => "4237",
    "Malden Center" => "4238",
    "Massachusetts Avenue" => "4239",
    "Mission Park" => "4240",
    "Museum of Fine Arts" => "4241",
    "Newton Centre" => "4242",
    "Northeastern University" => "4243",
    "Packards Corner" => "4244",
    "Riverway" => "4245",
    "Saint Mary’s Street" => "4246",
    "Saint Paul Street" => "4247",
    "Science Park West-End" => "4248",
    "South Street" => "4249",
    "Summit Avenue" => "4250",
    "Sutherland Road" => "4251",
    "Tappan Street" => "4252",
    "Tufts Medical Center" => "4253",
    "Warren Street" => "4254",
    "Washington Square" => "4255",
    "Washington Street" => "4256",
    "Medford/Tufts" => "852"
  })
  |> Map.new(fn {name, id} -> {normalize_name.(name), id} end)

signs_json =
  File.read!("priv/signs.json")
  |> Jason.decode!(keys: :atoms)

# headsign_to_destination

Enum.flat_map(signs_json, fn
  %{source_config: source_config} -> List.wrap(source_config)
  %{configs: configs} -> configs
  %{top_configs: top_configs, bottom_configs: bottom_configs} -> top_configs ++ bottom_configs
end)
|> Enum.map(& &1[:headway_direction_name])
|> Enum.uniq()
|> Enum.reject(&(&1 in [nil, "Seaport"]))
|> Enum.sort()
|> Enum.map_join("\n", fn name ->
  id =
    case id_lookup[name] do
      nil -> String.downcase(name) |> String.to_atom()
      id -> id
    end

  ~s[  def headsign_to_destination(#{inspect(name)}), do: #{inspect(id)}]
end)
|> IO.puts()

# destination_to_sign_string

Enum.map(data, fn stop ->
  id = stop["id"]
  abbrev = abbrev_lookup[normalize_name.(stop["attributes"]["name"])]
  {id, abbrev}
end)
|> Enum.concat([
  {"place-chels", "Chelsea"},
  {:northbound, "Northbound"},
  {:southbound, "Southbound"},
  {:eastbound, "Eastbound"},
  {:westbound, "Westbound"},
  {:inbound, "Inbound"},
  {:outbound, "Outbound"},
  {:silver_line, "SL Outbound"}
])
|> Enum.sort_by(&elem(&1, 0))
|> Enum.map_join("\n", fn {id, abbrev} ->
  ~s[  def destination_to_sign_string(#{inspect(id)}), do: #{inspect(abbrev)}]
end)
|> IO.puts()

# audio_take

Enum.map(data, fn stop ->
  id = stop["id"]
  name = stop["attributes"]["name"]
  take_id = take_lookup[normalize_name.(name)]
  {id, take_id}
end)
|> Enum.concat([
  {"place-chels", "860"},
  {:northbound, "788"},
  {:southbound, "787"},
  {:eastbound, "867"},
  {:westbound, "868"},
  {:inbound, "33003"},
  {:outbound, "33004"},
  {:silver_line, "931"}
])
|> Enum.sort_by(&elem(&1, 0))
|> Enum.map_join("\n", fn {id, take_id} ->
  ~s[  def audio_take(#{inspect(id)}), do: #{inspect(take_id)}]
end)
|> IO.puts()

# destination_to_ad_hoc_string

Enum.map(data, fn stop ->
  id = stop["id"]
  name = stop["attributes"]["name"]
  {id, name}
end)
|> Enum.concat([
  {"place-chels", "Chelsea"},
  {:northbound, "Northbound"},
  {:southbound, "Southbound"},
  {:eastbound, "Eastbound"},
  {:westbound, "Westbound"},
  {:inbound, "Inbound"},
  {:outbound, "Outbound"},
  {:silver_line, "Silver Line Outbound"}
])
|> Enum.sort_by(&elem(&1, 0))
|> Enum.map_join("\n", fn {id, name} ->
  ~s[  def destination_to_ad_hoc_string(#{inspect(id)}), do: #{inspect(name)}]
end)
|> IO.puts()
