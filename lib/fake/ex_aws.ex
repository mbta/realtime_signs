defmodule Fake.ExAws do
  def get_object(bucket, path) do
    {bucket, path}
  end

  def request({"error", _path}) do
    {:error, "bad"}
  end
  def request({_bucket, _path}) do
    {:ok, %{
      body: "{\"chelsea_inbound\":{\"enabled\":true}}",
      headers: [
        {"x-amz-id-2", "id1235"},
        {"x-amz-request-id", "REQUEST1235"},
        {"Date", "Thu, 17 May 2018 19:15:48 GMT"},
        {"Last-Modified", "Thu, 17 May 2018 18:59:16 GMT"},
        {"ETag", "\"deadbeef1234\""},
        {"Accept-Ranges", "bytes"},
        {"Content-Type", "application/octet-stream"},
        {"Content-Length", "168"},
        {"Server", "AmazonS3"}
      ],
    status_code: 200
  }}
  end
end
