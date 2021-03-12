defmodule Engine.NetworkCheck.HackneyTest do
  use ExUnit.Case, async: true
  alias Test.Support.Helpers

  defmodule MockBadNetwork do
    def unquote(:do)(_data), do: {:proceed, [response: {500, 'Not OK'}]}
  end

  defmodule MockGoodNetwork do
    def unquote(:do)(_data), do: {:proceed, [response: {200, 'OK'}]}
  end

  describe "check/0" do
    test "returns :ok on valid check" do
      {:ok, pid, port} = Helpers.start_server(MockGoodNetwork)
      on_exit(fn -> :inets.stop(:httpd, pid) end)

      assert Engine.NetworkCheck.Hackney.check("http://localhost:#{port}/") == :ok
    end

    test "returns :error on failure" do
      {:ok, pid, port} = Helpers.start_server(MockBadNetwork)
      on_exit(fn -> :inets.stop(:httpd, pid) end)

      assert Engine.NetworkCheck.Hackney.check("http://localhost:#{port}/") == :error
    end
  end
end
