# Generates code for a bus route destination function using data from the API

Mix.install([
  {:httpoison, "~> 1.0"},
  {:jason, "~> 1.4.0"}
])

route_ids =
  for %{"type" => "bus"} = sign <- File.read!("priv/signs.json") |> Jason.decode!(),
      config_list <- [sign["configs"], sign["top_configs"], sign["bottom_configs"]],
      config_list,
      %{"sources" => sources} <- config_list,
      %{"route_id" => route_id} <- sources,
      uniq: true do
    route_id
  end
  |> Enum.sort_by(fn s -> Integer.parse(s) |> elem(0) end)

req =
  HTTPoison.get!(
    System.get_env("API_V3_URL") <> "/routes",
    [{"x-api-key", System.get_env("API_V3_KEY")}],
    timeout: 2000,
    recv_timeout: 2000,
    params: %{"filter[type]" => "3"}
  )

%{"data" => data} = Jason.decode!(req.body)

dest_lookup =
  for route <- data, into: %{} do
    {route["id"], route["attributes"]["direction_destinations"]}
  end

Enum.flat_map(route_ids, fn route_id ->
  Map.get(dest_lookup, route_id, ["", ""])
  |> Enum.with_index()
  |> Enum.map(fn {dest, dir} ->
    "  def bus_route_destination(#{inspect(route_id)}, #{inspect(dir)}), do: #{inspect(dest)}"
  end)
end)
|> Enum.join("\n")
|> IO.puts()
