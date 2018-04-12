defmodule Signs.Sign do
  use GenServer
  require Logger

  defstruct [
    :id, :pa_ess_id, :gtfs_stop_id, :route_id, :current_content
  ]

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(%{"type" => "normal"} = config) do
    schedule_update(self())

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      route_id: config["route_id"],
      current_content: nil
    }

    {:ok, sign}
  end

  def handle_info(:update_content, sign) do
    schedule_update(self())

    content =
      sign.gtfs_stop_id
      |> Engine.Predictions.for_stop
      |> Content.Predictions.from_times

    if content == sign.current_content do
      {:noreply, sign}
    else
      PaEssUpdater.update_sign(sign.pa_ess_id, content)
      {:noreply, %{sign | current_content: content}}
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 1_000)
  end
end
