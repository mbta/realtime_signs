defmodule PaEss.HttpUpdaterTest do
  use ExUnit.Case, async: true

  describe "update_sign/5" do
    test "Posts a request to display a message now" do
      state = %{http_poster: Fake.HTTPoison, uid: 0}
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :boarding}

      assert {:reply, {:ok, :sent}, %{state | uid: 1}} == PaEss.HttpUpdater.handle_call({:update_sign, {"ABCD", "n"}, 1, msg, 60, :now}, self(), state)
    end

    test "Returns an error if HTTP response code is not 2XX" do
      state = %{http_poster: Fake.HTTPoison, uid: 0}
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :arriving}

      assert {:reply, {:error, :bad_status}, %{state | uid: 1}} == PaEss.HttpUpdater.handle_call({:update_sign, {"bad_sign", "n"}, 1, msg, 60, 1234}, self(), state)
    end

    test "Returns an error if HTTP request fails" do
      state = %{http_poster: Fake.HTTPoison, uid: 0}
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: 2}

      assert {:reply, {:error, :post_error}, %{state | uid: 1}} == PaEss.HttpUpdater.handle_call({:update_sign, {"timeout", "n"}, 1, msg, 60, 1234}, self(), state)
    end
  end
end
