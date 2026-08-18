defmodule Engine.ChelseaBridgeTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    put_env_with_restore(
      chelsea_bridge_username: "username",
      chelsea_bridge_password: "password"
    )

    :ok
  end

  defp put_env_with_restore(overrides) do
    previous_values =
      Enum.map(overrides, fn {key, _value} ->
        {key, Application.fetch_env(:realtime_signs, key)}
      end)

    Enum.each(overrides, fn {key, value} ->
      Application.put_env(:realtime_signs, key, value)
    end)

    on_exit(fn ->
      Enum.each(previous_values, fn
        {key, {:ok, value}} -> Application.put_env(:realtime_signs, key, value)
        {key, :error} -> Application.delete_env(:realtime_signs, key)
      end)
    end)
  end

  defmodule FakePoster do
    def post(_, options \\ []) do
      q = Keyword.fetch!(options, :form)
      fake_response = %{"access_token" => "fake_token", "expires_in" => 3600}
      send(self(), {:post, q})
      {:ok, %Req.Response{status: 200, body: fake_response}}
    end
  end

  defmodule ErrorPoster do
    def post(_, _options \\ []), do: {:error, :token_request_failed}
  end

  defmodule SpyHttpClient do
    def get(url, _options \\ []) do
      send(self(), {:bridge_status_get_called, url})
      {:error, :should_not_be_called}
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
      put_env_with_restore(http_poster_mod: FakePoster)

      now = DateTime.utc_now()

      token = Engine.ChelseaBridge.update_api_token(now)

      assert token.value == "fake_token"
      assert DateTime.compare(token.expiration, now) == :gt
    end
  end

  describe "handle_info/2" do
    test "skips bridge status request when token fetch fails" do
      put_env_with_restore(
        http_client: SpyHttpClient,
        http_poster_mod: ErrorPoster
      )

      table = :ets.new(:bridge_status_skip_test, [:named_table])
      now = DateTime.utc_now()

      state = %{table: table, token: %{value: nil, expiration: now}}

      assert {:noreply, ^state} = Engine.ChelseaBridge.handle_info(:update, state)
      refute_receive {:bridge_status_get_called, _}
    end
  end
end
