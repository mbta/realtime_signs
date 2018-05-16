defmodule ExternalConfig.Local do
  @spec get :: map()
  def get() do
    "priv/config.json"
    |> File.read!()
    |> Poison.Parser.parse!()
  end
end
