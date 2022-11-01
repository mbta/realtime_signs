defmodule Jobs.MessageLatencyReport do
  @moduledoc """

  """
  require Logger

  @percentile_95 0.95
  @percentile_99 0.99

  def generate_message_latency_report(days_to_analyze \\ 7) do
    Enum.each(1..days_to_analyze, fn diff ->
      date = Date.utc_today() |> Date.add(-diff) |> Date.to_string()
      Logger.info("Generating message latency report for #{date}...")
      analyze_files_for_date(date)
    end)
  end

  defp analyze_files_for_date(date) do
    with {:ok, response} <- get_zip_file(date),
         {:ok, files} <- :zip.unzip(response.body) do
      unzipped_directory = String.replace(date, "-", "")
      # TODO: Switch this to Windows equivalent
      :os.cmd(:"cat #{unzipped_directory}/*.csv > #{unzipped_directory}/all.csv")

      [
        get_csv_row("#{unzipped_directory}/all.csv")
        | Enum.map(files, &get_csv_row/1)
      ]
      |> get_csv_data()
      |> put_csv_in_s3(date)

      Logger.info("Done processing. Deleting #{unzipped_directory}...")
      File.rm_rf!(unzipped_directory)
    else
      {:error, {:http_error, 404, _}} ->
        Logger.info("S3 response error: Unable to find zip file")

      {:error, :einval} ->
        Logger.info("Unzip error: Occured while attempting to unzip")

      {:error, reason} ->
        Logger.info("Message latency error: #{inspect(reason)}")
    end
  end

  defp get_zip_file(date) do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    path = "#{s3_paess_logs_path()}/#{date}.zip"

    Logger.info("Getting message log files at #{path}")
    s3_client.get_object(s3_bucket(), path) |> aws_client.request()
  end

  defp get_csv_row(file) do
    row = [
      get_id_from_filename(file) | File.stream!(file) |> analyze_file()
    ]

    row
  end

  defp analyze_file(file_contents) do
    rows_with_indices = parse_rows_and_add_indices(file_contents)

    num_rows = Enum.count(rows_with_indices)

    percentile_95_row =
      num_rows
      |> calculate_percentile_index(@percentile_95)
      |> get_percentile_row(rows_with_indices)

    percentile_99_row =
      num_rows
      |> calculate_percentile_index(@percentile_99)
      |> get_percentile_row(rows_with_indices)

    [percentile_95_row[:seconds], percentile_99_row[:seconds], num_rows]
  end

  defp parse_rows_and_add_indices(file_contents) do
    file_contents
    |> Stream.map(&String.trim(&1, "\n"))
    |> Stream.map(&String.split(&1, ","))
    |> Stream.filter(fn
      # Filter out header rows
      ["id" | _] ->
        false

      _ ->
        true
    end)
    |> Stream.map(fn [id, begin_date, end_date, count, seconds, station] ->
      [
        id: id,
        begin_date: begin_date,
        end_date: end_date,
        count: count,
        seconds: Float.parse(seconds) |> elem(0),
        station: station
      ]
    end)
    |> Enum.sort_by(fn row -> row[:seconds] end)
    |> Enum.with_index()
  end

  defp get_csv_data(rows) do
    # Put the data in CSV format with header row
    Logger.info("Creating CSV rows...")

    for row <- rows, into: "id,95th_percentile,99th_percentile,count\n" do
      Enum.join(row, ",") <> "\n"
    end
  end

  defp put_csv_in_s3(rows, date) do
    report_filename = "#{date}-message_latency.csv"

    with :ok <- File.write!(report_filename, rows) do
      s3_client = Application.get_env(:realtime_signs, :s3_client)
      aws_client = Application.get_env(:realtime_signs, :aws_client)

      Logger.info(
        "Storing report in S3 at #{s3_bucket()}/#{s3_paess_reports_path()}/#{report_filename}..."
      )

      case s3_client.put_object(
             s3_bucket(),
             "#{s3_paess_reports_path()}/#{report_filename}",
             File.read!(report_filename)
           )
           |> aws_client.request() do
        {:ok, _} ->
          Logger.info("Message latency report was successfully stored in S3")

        {:error, response} ->
          Logger.error(
            "Message latency report was not able to be stored. Response: #{inspect(response)}"
          )
      end
    end

    Logger.info("Deleting file at path #{report_filename}")
    File.rm!(report_filename)
  end

  defp get_id_from_filename(file_name) do
    [_date, station_code] =
      file_name |> to_string |> String.upcase() |> String.trim(".CSV") |> String.split("/")

    station_code
  end

  defp get_percentile_row(percentile_index, rows_with_index) do
    {percentile_row, _index} =
      Enum.find(rows_with_index, {[], nil}, fn {_row, index} ->
        index == percentile_index
      end)

    percentile_row
  end

  defp calculate_percentile_index(num_rows, percentile) do
    (num_rows - 1)
    |> Kernel.*(percentile)
    |> round()
  end

  defp s3_bucket, do: Application.get_env(:realtime_signs, :message_log_s3_bucket)
  defp s3_paess_logs_path, do: Application.get_env(:realtime_signs, :message_log_s3_folder)

  defp s3_paess_reports_path,
    do: Application.get_env(:realtime_signs, :message_log_report_s3_folder)
end
