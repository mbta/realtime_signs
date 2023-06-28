# Reads historical prediction data and generates a CSV with a minute-by-minute breakdown of the
# closest prediction at the specified stops during the specified time period.

Mix.install([
  {:ex_aws_s3, "~> 2.0"},
  {:ex_aws, "~> 2.0"},
  {:configparser_ex, "~> 4.0"},
  {:hackney, "~> 1.18.1"},
  {:sweet_xml, "~> 0.7.3"},
  {:jason, "~> 1.4.0"},
  {:csv, "~> 3.0.5"}
])

bucket = "mbta-gtfs-s3"

# Sign ids to report on, from signs.json
sign_ids = ["amory_st_eastbound"]
# Start time for reporting, in UTC
start = ~U[2023-06-01 08:00:00Z]
# How many minutes after start time to report
minutes = 180

config = [access_key_id: {:awscli, "default", 30}, secret_access_key: {:awscli, "default", 30}]

pad = fn v, n -> Integer.to_string(v) |> String.pad_leading(n, "0") end

all_signs = File.read!("priv/signs.json") |> Jason.decode!(keys: :atoms)
signs_lookup = for sign <- all_signs, into: %{}, do: {sign.id, sign}

rows =
  Range.new(0, minutes)
  |> Enum.map(fn index ->
    IO.write(".")
    date = DateTime.add(start, index, :minute)
    yyyy = pad.(date.year, 4)
    mm = pad.(date.month, 2)
    dd = pad.(date.day, 2)
    h = pad.(date.hour, 2)
    m = pad.(date.minute, 2)

    response =
      ExAws.S3.list_objects(bucket,
        prefix: "concentrate/#{yyyy}/#{mm}/#{dd}/#{yyyy}-#{mm}-#{dd}T#{h}:#{m}"
      )
      |> ExAws.request!(config)

    obj = Enum.find(response.body.contents, &String.contains?(&1.key, "rtr_TripUpdates"))
    {:ok, now, 0} = DateTime.from_iso8601(obj.last_modified)

    response = ExAws.S3.get_object(bucket, obj.key) |> ExAws.request!(config)

    predictions_lookup =
      for e <- Jason.decode!(response.body, keys: :atoms).entity,
          tu = e.trip_update,
          tu.trip.schedule_relationship != "CANCELED",
          stu <- tu.stop_time_update,
          (stu.arrival || stu.departure) && stu[:stops_away] do
        %{
          stop_id: stu.stop_id,
          direction_id: tu.trip.direction_id,
          route_id: tu.trip.route_id,
          timestamp:
            cond do
              stu.arrival -> stu.arrival.time
              stu.departure -> stu.departure.time
            end
        }
      end
      |> Enum.group_by(&{&1.stop_id, &1.direction_id})

    ["#{h}:#{m}"] ++
      Enum.map(sign_ids, fn sign_id ->
        %{source_config: %{sources: sources}} = Map.fetch!(signs_lookup, sign_id)

        Enum.flat_map(sources, fn source ->
          Map.get(predictions_lookup, {source.stop_id, source.direction_id}, [])
          |> Enum.filter(&(source.routes == nil or &1.route_id in source.routes))
        end)
        |> case do
          [] ->
            nil

          list ->
            Enum.min_by(list, & &1.timestamp).timestamp
            |> DateTime.from_unix!()
            |> DateTime.diff(now, :minute)
        end
      end)
  end)

csv = CSV.encode([[nil] ++ sign_ids] ++ rows) |> Enum.join()
File.write!("#{DateTime.to_date(start)}.csv", csv)
