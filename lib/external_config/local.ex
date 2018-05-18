defmodule ExternalConfig.Local do
  @spec get(Engine.Config.version_id):: {Engine.Config.version_id, map()}
  def get(_current_version) do
    config = "priv/config.json"
    |> File.read!()
    |> Poison.Parser.parse!()
    {nil, config}
  end
end
