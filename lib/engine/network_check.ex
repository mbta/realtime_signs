defmodule Engine.NetworkCheck do
  @callback check() :: :ok | :error
end
