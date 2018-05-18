defmodule ExternalConfig.S3 do
  require Logger

  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get(current_version) do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :s3_bucket)
    path = Application.get_env(:realtime_signs, :s3_path)
    case s3_client.get_object(bucket, path, [if_none_match: current_version]) |> aws_client.request() do
      {:ok, %{status_code: 304}} ->
        :unchanged
      {:ok, response} ->
        body = response.body
        |> Poison.Parser.parse!()

        etag = response.headers
               |> Enum.into(%{})
               |> Map.get("ETag")
        {etag, body}
      {:error, e} ->
        Logger.error "s3 response error: #{inspect e}"
        {nil, %{}}
    end
  end
end
