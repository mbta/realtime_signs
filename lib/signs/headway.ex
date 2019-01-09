defmodule Signs.Headway do
  use GenServer
  require Logger

  @enforce_keys [
    :id,
    :pa_ess_id,
    :gtfs_stop_id,
    :route_id,
    :headsign,
    :headway_engine,
    :bridge_engine,
    :sign_updater,
    :read_sign_period_ms
  ]

  defstruct @enforce_keys ++
              [
                :bridge_id,
                :current_content_bottom,
                :current_content_top,
                :timer,
                :bridge_delay_duration
              ]

  @type t :: %{
          id: String.t(),
          pa_ess_id: PaEss.id(),
          gtfs_stop_id: String.t(),
          route_id: String.t(),
          headsign: String.t(),
          headway_engine: module(),
          bridge_engine: module(),
          sign_updater: module(),
          current_content_bottom: Content.Message.t() | nil,
          current_content_top: Content.Message.t() | nil,
          bridge_id: String.t(),
          timer: reference() | nil,
          read_sign_period_ms: integer(),
          bridge_delay_duration: integer() | nil
        }

  @default_duration 120

  def start_link(%{"type" => "headway"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    headway_engine = opts[:headway_engine] || Engine.Headways
    bridge_engine = opts[:bridge_engine] || Engine.Bridge

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      pa_ess_id: {Map.fetch!(config, "pa_ess_loc"), Map.fetch!(config, "pa_ess_zone")},
      gtfs_stop_id: Map.fetch!(config, "gtfs_stop_id"),
      route_id: Map.fetch!(config, "route_id"),
      headsign: Map.fetch!(config, "headsign"),
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      bridge_id: config["bridge_id"],
      timer: nil,
      sign_updater: sign_updater,
      headway_engine: headway_engine,
      bridge_engine: bridge_engine,
      read_sign_period_ms: 5 * 60 * 1000
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_update(self())
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    {:ok, sign}
  end

  def handle_info(:update_content, sign) do
    schedule_update(self())

    updated_sign =
      if Engine.Config.enabled?(sign.id) do
        case sign.bridge_engine.status(sign.bridge_id) do
          {"Raised", duration} ->
            %{
              sign
              | current_content_top: %Content.Message.Bridge.Up{},
                current_content_bottom: %Content.Message.Bridge.Delays{},
                bridge_delay_duration: clean_duration(duration)
            }

          _ ->
            %{
              sign
              | current_content_top: %Content.Message.Headways.Top{
                  headsign: sign.headsign,
                  vehicle_type: vehicle_type(sign.route_id)
                },
                current_content_bottom:
                  bottom_content(sign.headway_engine.get_headways(sign.gtfs_stop_id)),
                bridge_delay_duration: nil
            }
        end
      else
        %{
          sign
          | current_content_top: Content.Message.Empty.new(),
            current_content_bottom: Content.Message.Empty.new()
        }
      end

    sign = send_update(sign, updated_sign)
    {:noreply, sign}
  end

  def handle_info(:read_sign, sign) do
    schedule_reading_sign(self(), sign.read_sign_period_ms)
    read_headway(sign)
    {:noreply, sign}
  end

  def handle_info(:expire, sign) do
    {:noreply,
     %{
       sign
       | current_content_top: Content.Message.Empty.new(),
         current_content_bottom: Content.Message.Empty.new()
     }}
  end

  def handle_info(:bridge_announcement_update, sign) do
    if sign.current_content_top == %Content.Message.Bridge.Up{} do
      read_bridge_messages(sign)
      schedule_bridge_announcement_update(self())
    end

    {:noreply, sign}
  end

  def handle_info(msg, sign) do
    Logger.warn("#{__MODULE__} #{inspect(sign.id)} unknown message: #{inspect(msg)}")
    {:noreply, sign}
  end

  defp send_update(%{current_content_bottom: same}, %{current_content_bottom: same} = sign) do
    sign
  end

  defp send_update(
         old_sign,
         %{current_content_top: new_top, current_content_bottom: new_bottom} = sign
       ) do
    sign.sign_updater.update_sign(sign.pa_ess_id, new_top, new_bottom, @default_duration, :now)

    if bridge_is_newly_up?(old_sign, sign) do
      read_bridge_messages(sign)
      schedule_bridge_announcement_update(self())
    end

    if sign.timer, do: Process.cancel_timer(sign.timer)
    timer = Process.send_after(self(), :expire, @default_duration * 1000 - 5000)
    %{sign | current_content_top: new_top, current_content_bottom: new_bottom, timer: timer}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_content, 1_000)
  end

  defp schedule_reading_sign(pid, ms) do
    Process.send_after(pid, :read_sign, ms)
  end

  defp schedule_bridge_announcement_update(pid) do
    Process.send_after(pid, :bridge_announcement_update, 5 * 60 * 1_000)
  end

  defp vehicle_type("Mattapan"), do: :trolley
  defp vehicle_type("743"), do: :bus
  defp vehicle_type("Green-D"), do: :subway

  defp bottom_content({:first_departure, range, first_departure}) do
    max_headway = Headway.ScheduleHeadway.max_headway(range)
    time_buffer = if max_headway, do: max_headway, else: 0
    current_time = Timex.now()

    if Headway.ScheduleHeadway.show_first_departure?(first_departure, current_time, time_buffer) do
      %Content.Message.Headways.Bottom{range: range}
    else
      Content.Message.Empty.new()
    end
  end

  defp bottom_content(range) do
    %Content.Message.Headways.Bottom{range: range}
  end

  defp bridge_is_newly_up?(old_sign, new_sign) do
    # e.g. from message expiration
    new_sign.current_content_top == %Content.Message.Bridge.Up{} and
      old_sign.current_content_top != %Content.Message.Bridge.Up{} and
      old_sign.current_content_top != Content.Message.Empty.new()
  end

  defp read_headway(%{current_content_bottom: msg} = sign) do
    {english, spanish} =
      Content.Audio.VehiclesToDestination.from_headway_message(msg, sign.headsign)

    for audio <- [english, spanish] do
      if audio, do: sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 120)
    end
  end

  defp read_bridge_messages(%{bridge_delay_duration: duration} = sign) do
    {english, spanish} = Content.Audio.BridgeIsUp.create_bridge_messages(duration)

    for audio <- [english, spanish] do
      if audio, do: sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 120)
    end
  end

  defp clean_duration(n) when is_integer(n) and n >= 1, do: n
  defp clean_duration(_), do: nil
end
