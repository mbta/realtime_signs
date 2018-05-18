defmodule ExternalConfig.Local do
  @spec get(Engine.Config.version_id):: {Engine.Config.version_id, map()} | :unchanged
  def get(current_version) do
    file  = "priv/config.json"
    |> File.read!()

    etag = file
           |> :erlang.phash2()

    if etag == current_version do
      :unchanged
    else
      config = file
      |> Poison.Parser.parse!()
      {etag, config}
    end
  end
end
