defmodule RealtimeSigns.MessageLogJob do
  require Logger

  def work do
    yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_string()
    Logger.info("Fetching message logs for #{yesterday}")
    # logs = get_logs(yesterday)
    Logger.info("Received message logs and storing in S3")
    # store_logs(logs, yesterday)

    IO.puts(yesterday)
  end

  defp get_logs(date) do
    # 1. Request ARINC Headend server for logs for today's date as request param
    http_client = Application.get_env(:realtime_signs, :http_poster_mod)
    http_client.get("#{zip_file_url()}/#{date}")
  end

  defp store_logs(logs, date) do
    # 2. Dump logs into S3
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :message_log_s3_bucket)
    path = Application.get_env(:realtime_signs, :message_log_s3_path)

    # path should include today's date
    s3_client.put_object(bucket, "#{path}/#{date}", logs) |> aws_client.request()
  end

  defp head_end_host, do: Application.get_env(:realtime_signs, :sign_head_end_host)
  # TODO: update when we know the endpoint that ARINC sets up
  defp zip_file_url, do: "http://#{head_end_host()}/mbta/cgi-bin/"
end
