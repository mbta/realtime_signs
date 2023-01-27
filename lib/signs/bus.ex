defmodule Signs.Bus do
  use GenServer
  require Logger

  @enforce_keys [
    :id,
    :pa_ess_loc,
    :text_zone,
    :audio_zones,
    :sources,
    :config_engine,
    :prediction_engine
  ]
  defstruct @enforce_keys

  def start_link(sign, opts \\ []) do
    state = %__MODULE__{
      id: Map.fetch!(sign, "id"),
      pa_ess_loc: Map.fetch!(sign, "pa_ess_loc"),
      text_zone: Map.fetch!(sign, "text_zone"),
      audio_zones: Map.fetch!(sign, "audio_zones"),
      sources:
        for source <- Map.fetch!(sign, "sources") do
          %{
            stop_id: Map.fetch!(source, "stop_id"),
            routes:
              for route <- Map.fetch!(source, "routes") do
                %{
                  route_id: Map.fetch!(route, "route_id"),
                  direction_id: Map.fetch!(route, "direction_id")
                }
              end
          }
        end,
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

    %__MODULE__{
      id: id,
      sources: sources,
      config_engine: config_engine,
      prediction_engine: predictions_engine
    } = state

    _config = config_engine.sign_config(id)
    current_time = Timex.now()

    _predictions =
      for %{stop_id: stop_id, routes: routes} <- sources,
          prediction <- predictions_engine.predictions_for_stop(stop_id),
          Enum.any?(
            routes,
            &(&1.route_id == prediction.route_id && &1.direction_id == prediction.direction_id)
          ) do
        prediction
      end
      # Exclude predictions whose times are missing or out of bounds
      |> Stream.reject(
        &(!&1.departure_time ||
            Timex.before?(&1.departure_time, Timex.shift(current_time, seconds: -5)))
      )
      # Special case: exclude 89.2 OB to Davis
      |> Stream.reject(&(&1.stop_id == "5104" && String.starts_with?(&1.headsign, "Davis")))
      # Special case: exclude routes terminating at Braintree (230.4 IB, 236.3 OB)
      |> Stream.reject(&(&1.stop_id == "38671" && String.starts_with?(&1.headsign, "Braintree")))
      # Special case: exclude routes terminating at Mattapan, in case those variants of route 24 come back.
      |> Stream.reject(
        &(&1.stop_id in ["185", "18511"] && String.starts_with?(&1.headsign, "Mattapan"))
      )

    # Exclude missing headsign and/or display route (error?)

    # Hold prediction in case of count-up
    # Special case: Hold prediction for inbound SL1 with stale prediction

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
