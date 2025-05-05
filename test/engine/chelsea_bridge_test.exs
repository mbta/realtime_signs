defmodule Engine.ChelseaBridgeTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule FakePoster do
    def post(_, q, _) do
      fake_response = %{
        "access_token" => "fake_token",
        "expires_in" => 3600
      }

      fake_body = Jason.encode!(fake_response)

      send(self(), {:post, q})
      {:ok, %HTTPoison.Response{status_code: 200, body: fake_body}}
    end
  end

  describe "GenServer initialization" do
    test "GenServer starts up successfully" do
      {:ok, pid} =
        Engine.ChelseaBridge.start_link(
          gen_server_name: __MODULE__,
          bridge_ets_table_name: :bridge_status_test_table
        )

      Process.sleep(50)
      assert Process.alive?(pid)

      log =
        capture_log(fn ->
          send(pid, :unknown_message)
          Process.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown_message"
    end
  end

  describe "bridge_status/1" do
    test "bridge_status/1 returns default if ETS has no value" do
      :ets.new(:empty_bridge_status, [:named_table])

      assert Engine.ChelseaBridge.bridge_status(:empty_bridge_status) == %{
               raised?: nil,
               estimate: nil
             }
    end

    test "bridge_status/1 returns stored ETS data if present" do
      :ets.new(:bridge_status_test, [:named_table])

      :ets.insert(
        :bridge_status_test,
        {:value, %{raised?: true, estimate: ~U[2025-01-01 00:00:00Z]}}
      )

      assert Engine.ChelseaBridge.bridge_status(:bridge_status_test) == %{
               raised?: true,
               estimate: ~U[2025-01-01 00:00:00Z]
             }
    end
  end

  describe "update_api_token/1" do
    test "update_api_token/1 returns token with expiration" do
      now = DateTime.utc_now()

      Application.put_env(:realtime_signs, :chelsea_bridge_username, "username")
      Application.put_env(:realtime_signs, :chelsea_bridge_password, "password")
      Application.put_env(:realtime_signs, :http_poster_mod, FakePoster)

      token = Engine.ChelseaBridge.update_api_token(now)

      assert token.value == "fake_token"
      assert DateTime.compare(token.expiration, now) == :gt
    end
  end
end
