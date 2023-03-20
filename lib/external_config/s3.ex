defmodule ExternalConfig.S3 do
  require Logger

  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get(current_version) do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :s3_bucket)
    path = Application.get_env(:realtime_signs, :s3_path)

    case s3_client.get_object(bucket, path, if_none_match: current_version)
         |> aws_client.request() do
      {:ok, %{status_code: 304}} ->
        :unchanged

      {:ok, response} ->
        body = Jason.decode!(response.body)

        etag =
          response.headers
          |> Enum.into(%{})
          |> Map.get("ETag")

        {etag, body}

      {:error, e} ->
        Logger.error("s3 response error: #{inspect(e)}")
        {nil, %{}}
    end
  end

  def get_active_headend_ip() do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :s3_bucket)
    path = Application.get_env(:realtime_signs, :s3_active_headend_path)

    case s3_client.get_object(bucket, path)
         |> aws_client.request() do
      {:ok, response} ->
        body = Jason.decode!(response.body)
        {:ok, body["active_headend_ip"]}

      {:error, e} ->
        Logger.error("active_headend_ip: s3 response error: #{inspect(e)}")
        {:error, nil}
    end
  end

  def put_active_headend_ip(ip) do
    s3_client = Application.get_env(:realtime_signs, :s3_client)
    aws_client = Application.get_env(:realtime_signs, :aws_client)
    bucket = Application.get_env(:realtime_signs, :s3_bucket)
    path = Application.get_env(:realtime_signs, :s3_active_headend_path)

    case s3_client.put_object(bucket, path, Jason.encode!(%{active_headend_ip: ip}))
         |> aws_client.request() do
      {:ok, response} ->
        Logger.info("active_headend_ip: config changed to: #{ip}")
        {:ok, response}

      {:error, e} ->
        Logger.error("active_headend_ip: s3 response error: #{inspect(e)}")
        {:error, nil}
    end
  end
end
