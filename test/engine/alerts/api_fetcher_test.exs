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
                   "70061" => :suspension_closed_station,
                   "70063" => :suspension_closed_station,
                   "70064" => :suspension_closed_station,
                   "70065" => :suspension_closed_station,
                   "70066" => :suspension_closed_station,
                   "70067" => :suspension_closed_station,
                   "70068" => :suspension_closed_station,
                   "70069" => :suspension_closed_station,
                   "70070" => :suspension_closed_station,
                   "70071" => :suspension_closed_station,
                   "70072" => :suspension_closed_station,
                   "70073" => :suspension_closed_station,
                   "70074" => :suspension_closed_station,
                   "70075" => :suspension_closed_station,
                   "70076" => :suspension_closed_station,
                   "70077" => :suspension_closed_station,
                   "70078" => :suspension_closed_station,
                   "70079" => :suspension_closed_station,
                   "70080" => :suspension_closed_station,
                   "70081" => :suspension_closed_station,
                   "70082" => :suspension_closed_station,
                   "70083" => :suspension_closed_station,
                   "70084" => :suspension_closed_station,
                   "70085" => :suspension_closed_station,
                   "70086" => :suspension_closed_station,
                   "70087" => :suspension_closed_station,
                   "70088" => :suspension_closed_station,
                   "70089" => :suspension_closed_station,
                   "70090" => :suspension_closed_station,
                   "70091" => :suspension_closed_station,
                   "70092" => :suspension_closed_station,
                   "70093" => :suspension_closed_station,
                   "70094" => :suspension_closed_station,
                   "70095" => :suspension_closed_station,
                   "70096" => :suspension_closed_station,
                   "70097" => :suspension_closed_station,
                   "70098" => :suspension_closed_station,
                   "70099" => :suspension_closed_station,
                   "70100" => :suspension_closed_station,
                   "70101" => :suspension_closed_station,
                   "70102" => :suspension_closed_station,
                   "70103" => :suspension_closed_station,
                   "70104" => :suspension_closed_station,
                   "70105" => :suspension_closed_station
                 },
                 :route_statuses => %{
                   "1" => :suspension_closed_station,
                   "Red" => :suspension_closed_station,
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
