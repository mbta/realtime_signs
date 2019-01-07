defmodule RealtimeSignsTest do
  use ExUnit.Case, async: false

  describe "http_updater_children/0" do
    test "generates the right supervisor spec based on application config" do
      old_count = Application.get_env(:realtime_signs, :number_of_http_updaters)

      on_exit(fn ->
        Application.put_env(:realtime_signs, :number_of_http_updaters, old_count)
      end)

      Application.put_env(:realtime_signs, :number_of_http_updaters, 2)

      assert RealtimeSigns.http_updater_children() == [
               Supervisor.child_spec({PaEss.HttpUpdater, []}, id: :http_updater1),
               Supervisor.child_spec({PaEss.HttpUpdater, []}, id: :http_updater2)
             ]
    end
  end
end
