defmodule ExternalConfig.Local do
  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get(current_version) do
    {:ok, file} = File.read("priv/config.json")

    etag =
      file
      |> :erlang.phash2()
      |> Kernel.inspect()

    if etag == current_version do
      :unchanged
    else
      {etag, Poison.Parser.parse!(file)}
    end
  end
end
