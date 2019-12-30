defmodule RealtimeSignsConfig do
  @doc "Helper for setting configuration at runtime"
  @spec update_env(map(), atom(), String.t(), Keyword.t()) :: :ok | no_return()
  def update_env(env, app_key, env_var, opts \\ []) do
    type = Keyword.get(opts, :type, :string)

    case Map.get(env, env_var) do
      nil ->
        :ok

      value ->
        value =
          case type do
            :string -> value
            :integer -> String.to_integer(value)
          end

        Application.put_env(:realtime_signs, app_key, value)
        :ok
    end
  end
end
