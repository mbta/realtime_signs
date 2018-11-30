defmodule Engine.Alerts.ApiFetcherTest do
  use ExUnit.Case

  describe "get_stop_statuses/1" do
    test "downloads and parses the alerts" do
      assert {
               :ok,
               %{"70151" => :shuttles_transfer_station}
             } = Engine.Alerts.ApiFetcher.get_stop_statuses()
    end

    test "gracefully handles HTTP issue" do
      old_env = Application.get_env(:realtime_signs, :api_v3_url)
      Application.put_env(:realtime_signs, :api_v3_url, "https://notreal")
      on_exit(fn -> Application.put_env(:realtime_signs, :api_v3_url, old_env) end)

      assert {:error, _} = Engine.Alerts.ApiFetcher.get_stop_statuses()
    end
  end
end
