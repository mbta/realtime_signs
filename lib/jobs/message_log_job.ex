defmodule RealtimeSigns.MessageLogJob do
  def work do
    # 1. Request ARINC Headend server for logs

    # 2. Dump logs into S3
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :message_log_s3_bucket)
    path = Application.get_env(:realtime_signs, :message_log_s3_path)

    IO.puts(bucket)
  end

  defp head_end_host, do: Application.get_env(:realtime_signs, :sign_head_end_host)
  defp zip_file_url, do: "http://#{head_end_host()}/mbta/cgi-bin/RemoteMsgsCgi.exe"
end
