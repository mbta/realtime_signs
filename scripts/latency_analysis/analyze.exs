Mix.install([{:mail, "~> 0.2"}, {:nimble_csv, "~> 1.1"}])

require Logger

alias NimbleCSV.RFC4180, as: CSV

defmodule SignUpdate do
  defstruct [:uid, :station, :zone, :line, :content]

  defmodule Timing do
    defstruct sent_at: nil, received_at: nil, signs_received_at: %{}
  end

  def hash(%__MODULE__{uid: uid, station: station, zone: zone, line: line, content: content}) do
    (uid <> station <> zone <> to_string(line) <> content)
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode64(padding: false)
  end
end

defmodule Logs do
  @csv_file_pattern ~r/\.csv$/i
  @log_file_pattern ~r/\.(csv|log|txt)$/i

  def all(type) do
    type
    |> input_files()
    |> Stream.flat_map(fn file ->
      Logger.info("reading #{file}")
      log_lines(file)
    end)
  end

  defp input_files(type) do
    "input/#{type}"
    |> File.ls!()
    |> Enum.filter(&(&1 =~ @log_file_pattern))
    |> Enum.map(&"input/#{type}/#{&1}")
  end

  defp log_lines(filename) do
    # Assumes `.csv` files are Splunk CSV log exports with `_raw` as the first column
    if filename =~ @csv_file_pattern do
      filename |> raw_lines() |> CSV.parse_stream() |> Stream.map(&hd/1)
    else
      raw_lines(filename)
    end
  end

  defp raw_lines(filename), do: filename |> File.read!() |> String.splitter("\n", trim: true)
end

defmodule HTTPLogs do
  def sign_updates_with_timestamps(log_line) do
    if log_line =~ "MsgType=SignContent" do
      # By coincidence both realtime_signs logs and head-end server logs have the query string as
      # the 5th space-separated field; this might need to be adjusted if that changes
      [timestamp, _, _, _, "MsgType=SignContent&" <> query | _] = String.split(log_line)
      timestamp = timestamp |> String.replace(~w([ ]), "") |> NaiveDateTime.from_iso8601!()
      %{"uid" => [uid], "sta" => [station], "c" => commands} = decode_query(query)
      Enum.flat_map(commands, &sign_updates_from_command(&1, uid, station, timestamp))
    else
      []
    end
  end

  defp decode_query(query) do
    # Versus `URI.decode_query`, allows collecting multiple values for the same key
    query |> URI.query_decoder() |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp sign_updates_from_command("t" <> rest, _, _, _) do
    # Currently we never use this feature, so unsure if RTD_OK would be logged at the time the
    # message is received, or the time it is first displayed
    Logger.warning("not handling command with effective time: t#{rest}")
    []
  end

  @zone_line_pattern ~r/~([mcnsew])([12])/
  @content_pattern ~r/-"(.*?)"(?:.\d+)?/

  defp sign_updates_from_command(command, uid, station, timestamp) do
    [content] = Regex.run(@content_pattern, command, capture: :all_but_first)

    @zone_line_pattern
    |> Regex.scan(command, capture: :all_but_first)
    |> Enum.map(fn [zone, line] ->
      {
        %SignUpdate{
          uid: uid,
          station: station,
          zone: zone,
          line: String.to_integer(line),
          content: content
        },
        timestamp
      }
    end)
  end
end

defmodule SCULogs do
  def sign_update_with_timestamp(log_line) do
    if log_line =~ "RTD_OK" do
      [
        timestamp,
        "RTD_OK",
        <<station::binary-size(4), zone::binary-size(1), "SIGN", number::binary-size(3)>>,
        uid,
        content,
        attrs | _
      ] = String.split(log_line, "\t")

      {
        %SignUpdate{
          uid: uid,
          station: station,
          zone: String.downcase(zone),
          line: get_line(attrs),
          content: String.replace(content, "'", "")
        },
        number,
        parse_timestamp(timestamp)
      }
    else
      nil
    end
  rescue
    error ->
      Logger.warning(
        [
          "failed to parse SCU log line, skipping",
          "line: #{inspect(log_line)}",
          "error: #{Exception.message(error)}"
        ]
        |> Enum.join("\n  ")
      )

      nil
  end

  defp get_line(attrs) do
    case String.split(attrs) do
      [_, "Top" | _] -> 1
      [_, "Bottom" | _] -> 2
    end
  end

  defp parse_timestamp(timestamp),
    do: timestamp |> Mail.Parsers.RFC2822.erl_from_timestamp() |> NaiveDateTime.from_erl!()
end

defmodule Output do
  @headers ~w(key sent_at uid station zone line content seconds_to_head sign_num seconds_to_sign)

  def timings_to_csv(timings, filename) do
    Logger.info("writing #{filename}")
    output = File.stream!(filename, [:write, :delayed_write])

    timings
    |> Enum.sort_by(
      fn {_, %{sent_at: sent_at}} -> sent_at end,
      fn a, b -> NaiveDateTime.compare(a, b) != :gt end
    )
    |> Stream.flat_map(&update_to_csv_rows/1)
    |> then(fn rows -> Stream.concat([@headers], rows) end)
    |> CSV.dump_to_iodata()
    |> Enum.into(output)
  end

  defp update_to_csv_rows({update, %{signs_received_at: signs_received_at} = timing})
       when map_size(signs_received_at) > 0 do
    Enum.map(signs_received_at, fn {sign_number, sign_received_at} ->
      [
        SignUpdate.hash(update),
        NaiveDateTime.truncate(timing.sent_at, :second),
        update.uid,
        update.station,
        update.zone,
        update.line,
        update.content,
        maybe_time_diff(timing.received_at, timing.sent_at),
        sign_number,
        NaiveDateTime.diff(sign_received_at, timing.sent_at)
      ]
    end)
  end

  defp update_to_csv_rows({update, timing}) do
    [
      [
        SignUpdate.hash(update),
        NaiveDateTime.truncate(timing.sent_at, :second),
        update.uid,
        update.station,
        update.zone,
        update.line,
        update.content,
        maybe_time_diff(timing.received_at, timing.sent_at),
        nil,
        nil
      ]
    ]
  end

  defp maybe_time_diff(nil, _), do: ""
  defp maybe_time_diff(_, nil), do: ""
  defp maybe_time_diff(a, b), do: NaiveDateTime.diff(a, b)
end

defmodule Analyze do
  def run(output_filename, input_filter \\ nil) do
    make_initial_timings(input_filter)
    |> add_head_end_timings(input_filter)
    |> add_sign_received_timings()
    |> Output.timings_to_csv(output_filename)
  end

  defp make_initial_timings(filter) do
    Logs.all("realtime_signs")
    |> Stream.filter(&matches_filter?(&1, filter))
    |> Stream.flat_map(&HTTPLogs.sign_updates_with_timestamps/1)
    |> ensure_one_timestamp_per_update()
    |> Enum.into(%{}, fn {update, timestamp} ->
      {update, %SignUpdate.Timing{sent_at: timestamp}}
    end)
  end

  defp add_head_end_timings(initial_timings, filter) do
    Logs.all("head_end")
    |> Stream.filter(&matches_filter?(&1, filter))
    |> Stream.flat_map(&HTTPLogs.sign_updates_with_timestamps/1)
    |> ensure_one_timestamp_per_update()
    |> Enum.reduce(initial_timings, fn {update, timestamp}, timings ->
      case Map.get(timings, update) do
        nil -> timings
        timing -> Map.put(timings, update, %{timing | received_at: timestamp})
      end
    end)
  end

  defp add_sign_received_timings(timings_with_received_at) do
    Logs.all("scu")
    |> Stream.map(&SCULogs.sign_update_with_timestamp/1)
    |> Stream.reject(&is_nil/1)
    |> Enum.reduce(timings_with_received_at, fn {update, number, timestamp}, timings ->
      case Map.get(timings, update) do
        nil ->
          timings

        %{signs_received_at: %{^number => ^timestamp}} ->
          # Some SCU logs overlap; this just means we saw the same log entry more than once
          timings

        %{signs_received_at: %{^number => _}} ->
          Logger.warning("sign #{number} received update more than once: #{inspect(update)}")
          timings

        %{signs_received_at: signs_received_at} = timing ->
          Map.put(timings, update, %{
            timing
            | signs_received_at: Map.put(signs_received_at, number, timestamp)
          })
      end
    end)
  end

  defp matches_filter?(_, nil), do: true
  defp matches_filter?(log_line, filter), do: String.contains?(log_line, filter)

  defp ensure_one_timestamp_per_update(updates_with_timestamps) do
    updates_with_timestamps
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Stream.filter(fn
      {_update, [_timestamp]} ->
        true

      {update, _timestamps} ->
        Logger.warning("skipping multiple updates with same fields: #{inspect(update)}")
        false
    end)
    |> Stream.map(fn {update, [timestamp]} -> {update, timestamp} end)
  end
end

{options, []} = System.argv() |> OptionParser.parse!(strict: [filter: :string, output: :string])
input_filter = Keyword.get(options, :filter)
output_filename = Keyword.get(options, :output, "output/analysis.csv")

Analyze.run(output_filename, input_filter)
