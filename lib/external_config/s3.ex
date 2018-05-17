defmodule ExternalConfig.S3 do
  def get() do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :s3_bucket)
    path = Application.get_env(:realtime_signs, :s3_path)
    {:ok, %{body: body}} = s3_client.get_object(bucket, path) |> aws_client.request()

    body
    |> Poison.Parser.parse!()
  end
end
