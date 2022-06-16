defmodule RealtimeSigns.MessageLogJob do
  require Logger

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
    s3_client.put_object(bucket, path, file) |> aws_client.request()
  end

  defp zip_file_url, do: Application.get_env(:realtime_signs, :message_log_zip_url)
  defp s3_bucket, do: Application.get_env(:realtime_signs, :message_log_s3_bucket)
  defp s3_folder, do: Application.get_env(:realtime_signs, :message_log_s3_folder)
end
