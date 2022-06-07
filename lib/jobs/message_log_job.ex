defmodule RealtimeSigns.MessageLogJob do
  def work do
    # 1. Request ARINC Headend server for logs
    # 2. Dump logs into S3
    IO.puts("running job")
  end
end
