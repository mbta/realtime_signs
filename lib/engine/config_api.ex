defmodule Engine.ConfigAPI do
  @callback sign_config(String.t()) :: Engine.Config.sign_config()
  @callback headway_config(String.t(), DateTime.t()) :: Engine.Config.Headway.t() | nil
end
