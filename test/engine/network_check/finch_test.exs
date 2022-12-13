defmodule Engine.NetworkCheck.FinchTest do
  use ExUnit.Case, async: true
  alias Test.Support.Helpers

  defmodule MockBadNetwork do
    def unquote(:do)(_data), do: {:proceed, [response: {500, 'Not OK'}]}
  end

  defmodule MockGoodNetwork200 do
    def unquote(:do)(_data), do: {:proceed, [response: {200, 'OK'}]}
  end

  defmodule MockGoodNetwork204 do
    def unquote(:do)(_data), do: {:proceed, [response: {204, 'OK'}]}
  end

  describe "check/0" do
    test "returns :ok on valid check" do
      {:ok, pid, port} = Helpers.start_server(MockGoodNetwork200)
      on_exit(fn -> :inets.stop(:httpd, pid) end)

      assert Engine.NetworkCheck.Finch.check("http://localhost:#{port}/") == :ok
    end

    test "returns :ok on 204 response" do
      {:ok, pid, port} = Helpers.start_server(MockGoodNetwork204)
      on_exit(fn -> :inets.stop(:httpd, pid) end)

      assert Engine.NetworkCheck.Finch.check("http://localhost:#{port}/") == :ok
    end

    test "returns :error on failure" do
      {:ok, pid, port} = Helpers.start_server(MockBadNetwork)
      on_exit(fn -> :inets.stop(:httpd, pid) end)

      assert Engine.NetworkCheck.Finch.check("http://localhost:#{port}/") == :error
    end
  end
end
