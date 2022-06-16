defmodule RealtimeSigns.MessageLogJob do
  @moduledoc """
  CRON job that requests an endpoint that is hosted on ARINC's test server
  which serves a zip file containing log files with data on message latencies for every MBTA
  station with PA/ESS equipment for a given date.

  After fetching the zip file, the job simply stores them in an S3 bucket. The logs will be
  used for regular auditing of message latencies across the system.

  This is also an endpoint in RealtimeSignsWeb.MonitoringController that can be used to manually
  run the job. The purpose of this is twofold:
    1. Allow for easy test runs of the job.
    2. Allow for manual re-runs in case the job fails to run for some reason. This could be
    for a number reasons such as the ARINC server being unreachable, their aggregation script
    failing to collect all the logs, opstech3 being down, etc.
  """
  require Logger

  def get_and_store_logs() do
    Date.utc_today() |> Date.add(-1) |> Date.to_string() |> get_and_store_logs()
  end

  def get_and_store_logs(date) do
    Logger.info("Fetching message logs for #{date}")

    case get_logs(date) do
      {:ok, %{body: body}} ->
        store_logs(body, s3_bucket(), s3_folder(), date)

      {:error, reason} ->
        Logger.error("Message logs were not able to fetched. Response: #{inspect(reason)}")
    end
  end

  defp get_logs(date) do
    http_client = Application.get_env(:realtime_signs, :http_poster_mod)
    request_url = "#{zip_file_url()}/#{String.replace(date, "-", "")}"
    Logger.info("Making request to #{request_url}")
    http_client.get(request_url)
  end

  defp store_logs(file, bucket, folder, date) do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    path = "#{folder}/#{date}.zip"

    Logger.info("Storing logs in S3 at #{bucket}/#{path}...")

    case s3_client.put_object(bucket, path, file) |> aws_client.request() do
      {:ok, _} ->
        Logger.info("Message logs were successfully stored in S3")

      {:error, response} ->
        Logger.error("Message logs were not able to be stored. Response: #{inspect(response)}")
    end
  end

  defp zip_file_url, do: Application.get_env(:realtime_signs, :message_log_zip_url)
  defp s3_bucket, do: Application.get_env(:realtime_signs, :message_log_s3_bucket)
  defp s3_folder, do: Application.get_env(:realtime_signs, :message_log_s3_folder)
end
