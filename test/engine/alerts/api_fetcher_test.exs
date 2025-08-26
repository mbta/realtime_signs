defmodule Engine.Alerts.ApiFetcherTest do
  use ExUnit.Case

  describe "get_statuses/1" do
    test "downloads and parses the alerts" do
      assert Engine.Alerts.ApiFetcher.get_statuses([]) == {
               :ok,
               %{
                 :stop_statuses => %{
                   "70151" => :shuttles_transfer_station,
                   "70036" => :suspension_transfer_station,
                   "70034" => :suspension_closed_station,
                   "70033" => :suspension_transfer_station,
                   "70032" => :suspension_transfer_station,
                   "70063" => :station_closure,
                   "74636" => :station_closure,
                   "70261" => :shuttles_closed_station,
                   "70263" => :shuttles_closed_station,
                   "70264" => :shuttles_closed_station,
                   "70265" => :shuttles_closed_station,
                   "70266" => :shuttles_closed_station,
                   "70267" => :shuttles_closed_station,
                   "70268" => :shuttles_closed_station,
                   "70269" => :shuttles_closed_station,
                   "70270" => :shuttles_closed_station,
                   "70271" => :shuttles_closed_station,
                   "70272" => :shuttles_closed_station,
                   "70273" => :shuttles_closed_station,
                   "70274" => :shuttles_closed_station,
                   "70275" => :shuttles_closed_station,
                   "70276" => :shuttles_closed_station,
                   "170136" => :suspension_closed_station,
                   "170137" => :suspension_closed_station,
                   "170140" => :suspension_closed_station,
                   "170141" => :suspension_closed_station,
                   "70134" => :suspension_closed_station,
                   "70135" => :suspension_closed_station,
                   "70144" => :suspension_closed_station,
                   "70145" => :suspension_closed_station,
                   "70146" => :suspension_closed_station,
                   "70147" => :suspension_closed_station,
                   "70148" => :suspension_closed_station,
                   "70149" => :suspension_closed_station,
                   "71150" => :suspension_transfer_station,
                   "71151" => :suspension_transfer_station
                 },
                 :route_statuses => %{
                   "1" => :suspension_closed_station,
                   "Green-B" => :suspension_closed_station,
                   "Green-C," => :suspension_closed_station,
                   "Green-D," => :suspension_closed_station,
                   "Green-E," => :suspension_closed_station,
                   "Mattapan" => :shuttles_closed_station
                 }
               }
             }
    end

    test "gracefully handles HTTP issue" do
      old_env = Application.get_env(:realtime_signs, :api_v3_url)
      Application.put_env(:realtime_signs, :api_v3_url, "https://notreal")
      on_exit(fn -> Application.put_env(:realtime_signs, :api_v3_url, old_env) end)

      assert {:error, _} = Engine.Alerts.ApiFetcher.get_statuses([])
    end
  end
end
