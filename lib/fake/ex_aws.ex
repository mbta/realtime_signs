defmodule Fake.ExAws do
  def get_object(bucket, path, opts) do
    {bucket, path, opts}
  end

  def request({"error", _path, _opts}) do
    {:error, "bad"}
  end

  def request({_bucket, _path, [if_none_match: "unchanged"]}) do
    {:ok,
     %{
       body: "",
       headers: [
         {"x-amz-id-2",
          "Kxr1erO6Z7tPsKnHILg/IKIy+cuH3BhgK95eSQBeLkV1kWpNvIhT49pg29jF7xQ51FuIm2qMa6g="},
         {"x-amz-request-id", "83B8166DD0C44512"},
         {"Date", "Fri, 18 May 2018 14:55:01 GMT"},
         {"Last-Modified", "Thu, 17 May 2018 20:39:52 GMT"},
         {"ETag", "\"a06257c08d7f2a1ba638cb344f94f5e1\""},
         {"Server", "AmazonS3"}
       ],
       status_code: 304
     }}
  end

  def request({_bucket, _path, _opts}) do
    {:ok,
     %{
       body: "{\"chelsea_inbound\":{\"mode\":\"headway\"}}",
       headers: [
         {"x-amz-id-2", "id1235"},
         {"x-amz-request-id", "REQUEST1235"},
         {"Date", "Thu, 17 May 2018 19:15:48 GMT"},
         {"Last-Modified", "Thu, 17 May 2018 18:59:16 GMT"},
         {"ETag", "deadbeef1234"},
         {"Accept-Ranges", "bytes"},
         {"Content-Type", "application/octet-stream"},
         {"Content-Length", "168"},
         {"Server", "AmazonS3"}
       ],
       status_code: 200
     }}
  end
end
