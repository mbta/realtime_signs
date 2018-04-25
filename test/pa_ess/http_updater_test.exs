defmodule PaEss.HttpUpdaterTest do
  use ExUnit.Case, async: true

  describe "update_sign/5" do
    test "Posts a request to display a message now" do
      state = make_state()
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :boarding}

      assert {:reply, {:ok, :sent}, %{state | uid: 1}} == PaEss.HttpUpdater.handle_call({:update_sign, {"ABCD", "n"}, 1, msg, 60, :now}, self(), state)
    end

    test "Returns an error if HTTP response code is not 2XX" do
      state = make_state()
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :arriving}

      assert {:reply, {:error, :bad_status}, %{state | uid: 1}} == PaEss.HttpUpdater.handle_call({:update_sign, {"bad_sign", "n"}, 1, msg, 60, 1234}, self(), state)
    end

    test "Returns an error if HTTP request fails" do
      state = make_state()
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: 2}

      assert {:reply, {:error, :post_error}, %{state | uid: 1}} == PaEss.HttpUpdater.handle_call({:update_sign, {"timeout", "n"}, 1, msg, 60, 1234}, self(), state)
    end
  end

  describe "send_audio/4" do
    test "Buses to Chelsea" do
      state = make_state(%{uid: 1000})
      audio = %Content.Audio.BusesToDestination{
        language: :english,
        destination: :chelsea,
        next_bus_mins: 8,
        later_bus_mins: 12,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1001}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"SBOX", "e"}, audio, 5, :audio, 60}, self(), state)
    end

    test "Buses to South Station" do
      state = make_state(%{uid: 1001})
      audio = %Content.Audio.BusesToDestination{
        language: :english,
        destination: :south_station,
        next_bus_mins: 8,
        later_bus_mins: 12,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1002}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"SBSQ", "w"}, audio, 5, :audio, 60}, self(), state)
    end

    test "Chelsea bridge raised, expect delays" do
      state = make_state(%{uid: 1002})
      audio = %Content.Audio.ChelseaBridgeRaisedDelays{
        language: :english,
        delay_minutes: 10,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1003}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"SCHS", "w"}, audio, 5, :audio_visual, 200}, self(), state)
    end

    test "Buses to Chelsea, in Spanish" do
      state = make_state(%{uid: 1003})
      audio = %Content.Audio.BusesToDestination{
        language: :spanish,
        destination: :chelsea,
        next_bus_mins: 8,
        later_bus_mins: 14,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1004}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"SBOX", "e"}, audio, 5, :audio, 60}, self(), state)
    end

    test "Next train to Ashmont arrives in 4 minutes" do
      state = make_state(%{uid: 1004})
      audio = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        minutes: 4,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1005}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"MCED", "n"}, audio, 5, :audio, 60}, self(), state)
    end

    test "Train to Mattapan arriving" do
      state = make_state(%{uid: 1005})
      audio = %Content.Audio.TrainIsArriving{
        destination: :mattapan,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1006}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"MCED", "s"}, audio, 5, :audio, 60}, self(), state)
    end

    test "Train to Ashmont arriving" do
      state = make_state(%{uid: 1006})
      audio = %Content.Audio.TrainIsArriving{
        destination: :ashmont,
      }

      assert {:reply, {:ok, :sent}, %{state | uid: 1007}} ==
        PaEss.HttpUpdater.handle_call({:send_audio, {"MCAP", "n"}, audio, 5, :audio, 60}, self(), state)
    end
  end

  defp make_state(init \\ %{}) do
    Map.merge(%{http_poster: Fake.HTTPoison, uid: 0}, init)
  end
end
