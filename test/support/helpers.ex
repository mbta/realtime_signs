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
end
