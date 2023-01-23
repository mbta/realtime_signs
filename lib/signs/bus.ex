defmodule Signs.Bus do
  use GenServer
  require Logger

  def start_link(sign, opts \\ []) do
    %{
      "type" => "bus",
      "id" => id,
      "pa_ess_loc" => pa_ess_loc,
      "text_zone" => text_zone,
      "audio_zones" => audio_zones,
      "sources" => sources
    } = sign

    state = %{
      sign: %{
        id: id,
        pa_ess_loc: pa_ess_loc,
        text_zone: text_zone,
        audio_zones: audio_zones,
        sources:
          for %{"stop_id" => stop_id, "routes" => routes} <- sources do
            %{
              stop_id: stop_id,
              routes:
                for %{"route_id" => route_id, "direction_id" => direction_id} <- routes do
                  %{
                    route_id: route_id,
                    direction_id: direction_id
                  }
                end
            }
          end
      },
      config_engine: opts[:config_engine] || Engine.Config,
      prediction_engine: opts[:prediction_engine] || Engine.BusPredictions
    }

    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    schedule_run_loop(self())
    {:ok, state}
  end

  def handle_info(:run_loop, state) do
    schedule_run_loop(self())
    %{sign: sign, config_engine: config_engine, prediction_engine: predictions_engine} = state
    config = config_engine.sign_config(sign.id)
    current_time = Timex.now()

    predictions =
      for %{stop_id: stop_id, routes: routes} <- sign.sources,
          prediction <- predictions_engine.predictions_for_stop(stop_id),
          Enum.any?(
            routes,
            &(&1.route_id == prediction.route_id && &1.direction_id == prediction.direction_id)
          ),
          # Exclude predictions that are too old
          prediction.departure_time >= Timex.shift(current_time, seconds: -5),
          # Special case: exclude 89.2 OB to Davis
          !(prediction.stop_id == "5104" && String.starts_with?(prediction.headsign, "Davis")),
          # Special case: exclude routes terminating at Braintree (230.4 IB, 236.3 OB)
          !(prediction.stop_id == "38671" && String.starts_with?(prediction.headsign, "Braintree")),
          # Special case: exclude routes terminating at Mattapan, in case those variants of route 24 come back.
          !(prediction.stop_id in ["185", "18511"] &&
              String.starts_with?(prediction.headsign, "Mattapan")) do
        prediction
      end

    # Exclude missing headsign and/or display route (error?)

    # Hold prediction in case of count-up
    # Special case: Hold prediction for inbound SL1 with stale prediction

    _ = predictions
    _ = config

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Bus unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  def schedule_run_loop(pid) do
    Process.send_after(pid, :run_loop, 1_000)
  end

  # defp display_route(%{route_id: "749"}), do: "SL5"
  # defp display_route(%{route_id: "751"}), do: "SL4"
  # defp display_route(%{route_id: "743"}), do: "SL3"
  # defp display_route(%{route_id: "742"}), do: "SL2"
  # defp display_route(%{route_id: "741"}), do: "SL1"
  # defp display_route(%{route_id: "77", headsign: "North Cambridge"}), do: "77A"
  # defp display_route(%{route_id: "2427", stop_id: "185", headsign: headsign}) do
  #  cond do
  #    String.starts_with?(headsign, "Ashmont") -> "27"
  #    String.starts_with?(headsign, "Wakefield Av") -> "24"
  #    true -> "2427"
  #  end
  # end
  # defp display_route(%{route_id: route_id}), do: route_id
end
