defmodule Sign.Static.Parser.StaticText do
  require Logger
  alias Sign.Static

  @spec parse(String.t) :: [Sign.Static.Message.t]
  def parse(filename) do
    case File.read(filename) do
      {:ok, binary } ->
        parse_json_binary(binary)
      {:error, reason} ->
        Logger.warn("Could not read #{inspect filename}: #{inspect reason}")
        []
    end
  end

  @spec parse_json_binary(binary) :: [Sign.Static.Message.t]
  defp parse_json_binary(binary) do
    case Poison.decode(binary) do
      {:ok, static_text_map} ->
        Enum.map(static_text_map, &Static.Message.from_map/1)
      {:error, reason, _} ->
        Logger.warn("Could not parse static text file: #{inspect reason}")
        []
    end
  end
end
