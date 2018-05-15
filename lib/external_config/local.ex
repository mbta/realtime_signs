defmodule ExternalConfig.Local do
  def get() do
    "priv/config.json"
    |> File.read!()
    |> Poison.Parser.parse!()
  end
end
