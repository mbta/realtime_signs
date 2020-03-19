defmodule RealtimeSignsConfig do
  require Logger

  @doc "Helper for setting configuration at runtime"
  @spec update_env(map(), atom(), String.t(), Keyword.t()) :: :ok | no_return()
  def update_env(env, app_key, env_var, opts \\ []) do
    type = Keyword.get(opts, :type, :string)
    private? = Keyword.get(opts, :private?, false)

    case Map.get(env, env_var) do
      nil ->
        if type == :boolean do
          Application.put_env(:realtime_signs, app_key, false)
        end

        :ok

      value ->
        value =
          case type do
            :string -> value
            :integer -> String.to_integer(value)
            :boolean -> if value == "", do: false, else: true
          end

        unless private? do
          Logger.info("environment_variable #{env_var}=#{inspect(value)}")
        end

        Application.put_env(:realtime_signs, app_key, value)
        :ok
    end
  end
end
