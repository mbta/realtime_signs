defmodule ExternalConfig.S3 do
  @spec get :: map()
  def get() do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :s3_bucket)
    path = Application.get_env(:realtime_signs, :s3_path)
    case s3_client.get_object(bucket, path) |> aws_client.request() do
      {:ok, %{body: body}} ->
        body
        |> Poison.Parser.parse!()
      {:error, _} ->
        %{}
    end
  end
end
