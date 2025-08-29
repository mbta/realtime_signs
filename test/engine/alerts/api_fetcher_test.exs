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
                   "71151" => :suspension_transfer_station,
                   "70150" => :suspension_transfer_station,
                   "70154" => :suspension_transfer_station,
                   "70155" => :suspension_transfer_station,
                   "70160" => :suspension_closed_station,
                   "70161" => :suspension_closed_station,
                   "70162" => :suspension_closed_station,
                   "70163" => :suspension_closed_station,
                   "70164" => :suspension_closed_station,
                   "70165" => :suspension_closed_station,
                   "70166" => :suspension_closed_station,
                   "70167" => :suspension_closed_station,
                   "70168" => :suspension_closed_station,
                   "70169" => :suspension_closed_station,
                   "70170" => :suspension_closed_station,
                   "70171" => :suspension_closed_station,
                   "70172" => :suspension_closed_station,
                   "70173" => :suspension_closed_station,
                   "70174" => :suspension_closed_station,
                   "70175" => :suspension_closed_station,
                   "70176" => :suspension_closed_station,
                   "70177" => :suspension_closed_station,
                   "70178" => :suspension_closed_station,
                   "70179" => :suspension_closed_station,
                   "70180" => :suspension_closed_station,
                   "70181" => :suspension_closed_station,
                   "70182" => :suspension_closed_station,
                   "70183" => :suspension_closed_station,
                   "70186" => :suspension_closed_station,
                   "70187" => :suspension_closed_station,
                   "70239" => :suspension_closed_station,
                   "70240" => :suspension_closed_station,
                   "70241" => :suspension_closed_station,
                   "70242" => :suspension_closed_station,
                   "70243" => :suspension_closed_station,
                   "70244" => :suspension_closed_station,
                   "70501" => :suspension_transfer_station,
                   "70502" => :suspension_transfer_station,
                   "70505" => :suspension_closed_station,
                   "70506" => :suspension_closed_station,
                   "70507" => :suspension_closed_station,
                   "70508" => :suspension_closed_station,
                   "70509" => :suspension_closed_station,
                   "70510" => :suspension_closed_station,
                   "70511" => :suspension_closed_station,
                   "70512" => :suspension_closed_station,
                   "70513" => :suspension_closed_station,
                   "70514" => :suspension_closed_station
                 },
                 :route_statuses => %{
                   "1" => :suspension_closed_station,
                   "Green-B" => :suspension_closed_station,
                   "Green-C" => :suspension_closed_station,
                   "Green-D" => :suspension_closed_station,
                   "Green-E" => :suspension_closed_station,
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
