defmodule ExternalConfig.Local do
  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get(current_version) do
    file  = "priv/config.json"
    |> File.read!()

    etag = file
           |> :erlang.phash2()
           |> Kernel.inspect()

    if etag == current_version do
      :unchanged
    else
      config = file
      |> Poison.Parser.parse!()
      {etag, config}
    end
  end
end
