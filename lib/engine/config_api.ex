defmodule Engine.ConfigAPI do
  @callback sign_config(id :: String.t(), default :: Engine.Config.sign_config()) ::
              Engine.Config.sign_config()
  @callback headway_config(String.t(), DateTime.t()) :: Engine.Config.Headway.t() | nil
  @callback scu_migrated?(String.t()) :: boolean()
end
