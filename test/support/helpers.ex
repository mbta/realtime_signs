defmodule Test.Support.Helpers do
  defmacro reassign_env(var) do
    quote do
      old_value = Application.get_env(:realtime_signs, unquote(var))

      on_exit(fn ->
        Application.put_env(:realtime_signs, unquote(var), old_value)
      end)
    end
  end

  defmacro reassign_env(var, value) do
    quote do
      old_value = Application.get_env(:realtime_signs, unquote(var))
      Application.put_env(:realtime_signs, unquote(var), unquote(value))

      on_exit(fn ->
        Application.put_env(:realtime_signs, unquote(var), old_value)
      end)
    end
  end

  @doc "Starts an inets server and returns the port, for stubbing network requests"
  @spec start_server(module()) :: {:ok, pid(), integer()}
  def start_server(module) do
    {:ok, pid} =
      :inets.start(:httpd,
        server_name: 'TmpServer',
        server_root: '/tmp',
        document_root: '/tmp',
        port: 0,
        modules: [module]
      )

    port = :httpd.info(pid) |> Keyword.get(:port)

    {:ok, pid, port}
  end
end
