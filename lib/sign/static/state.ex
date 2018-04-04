defmodule Sign.Static.State do
  use GenServer
  alias Sign.Static
  alias Headway.ScheduleHeadway
  alias Sign.Static.Parser
  require Logger

  @bridge_id 1
  @default_opts [headway_refresh: 300_000, static_refresh: 20_000]

  def start_link(user_opts \\ []) do
    opts = Keyword.merge(@default_opts, user_opts)
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    schedule_refresh_headways(opts[:headway_refresh])
    schedule_refresh_static_text(opts[:static_refresh])
    headway_stations = :realtime_signs
                      |> Application.get_env(:headway_stations_config)
                      |> Parser.HeadwayStation.parse_static_station_ids()
                      |> Sign.Stations.Live.get_stations()

    static_text_stations = :realtime_signs
                           |> Application.get_env(:static_text_config)
                           |> Parser.StaticText.parse()

    {:ok, {headway_stations, static_text_stations}}
  end

  @doc "Returns a list of stations that are displaying static text"
  def static_station_codes(pid \\ __MODULE__) do
    GenServer.call(pid, :static_station_codes)
  end

  def handle_call(:static_station_codes, _from, {headway_stations, static_text_stations}) do
    headway_station_codes = Enum.map(headway_stations, & &1.sign_id)
    static_text_station_codes = Enum.map(static_text_stations, & &1.sign_id)
    {:reply, headway_station_codes ++ static_text_station_codes, {headway_stations, static_text_stations}}
  end

  def handle_info({:refresh_headways, refresh_time}, {headway_stations, static_text_stations}) do
    schedule_refresh_headways(refresh_time)
    station_ids = Enum.map(headway_stations, & &1.id)
    current_time = :realtime_signs |> Application.get_env(:time_zone) |> Timex.now()
    bridge_status = Bridge.Request.get_status(@bridge_id)
    schedule_headways = station_ids
                       |> Headway.Request.get_schedules()
                       |> ScheduleHeadway.group_headways_for_stations(station_ids, current_time)

    headway_stations
    |> Static.Messages.station_headway_messages(refresh_time, schedule_headways, current_time, bridge_status)
    |> send_station_messages(current_time)
    {:noreply, {headway_stations, static_text_stations}}
  end
  def handle_info({:refresh_static_text, refresh_time}, {headway_stations, static_text_stations}) do
    schedule_refresh_static_text(refresh_time)
    static_station_content = Static.Messages.station_static_messages(static_text_stations, refresh_time)
    send_station_messages(static_station_content, Timex.now())
    {:noreply, {headway_stations, static_text_stations}}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  def schedule_refresh_headways(refresh_time) do
    Process.send_after(self(), {:refresh_headways, refresh_time}, refresh_time)
  end
  def schedule_refresh_static_text(refresh_time) do
    Process.send_after(self(), {:refresh_static_text, refresh_time}, refresh_time)
  end

  defp send_station_messages(station_messages, current_time) do
    for station_message <- station_messages do
      Logger.info("#{station_message.station} :: #{inspect station_message.messages}")
      Sign.State.request(station_message, current_time)
    end
  end
end
