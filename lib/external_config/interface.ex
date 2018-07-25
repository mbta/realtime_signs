defmodule ExternalConfig.Interface do
  @callback get(Engine.Config.version_id()) :: {Engine.Config.version_id(), map()} | :unchanged
end
