defmodule Sign.Static.State do
  use GenServer
  alias Sign.Static
  alias Headway.ScheduleHeadway
  require Logger

  @bridge_id 1
  @default_opts [refresh_time: 300_000]

  def start_link(user_opts \\ []) do
    opts = Keyword.merge(@default_opts, user_opts)
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    schedule_refresh(opts[:refresh_time])
    static_stations = :realtime_signs
                      |> Application.get_env(:static_stations_config)
                      |> Static.Parser.parse_static_station_ids()
                      |> Sign.Stations.Live.get_stations()

    {:ok, static_stations}
  end

  @doc "Returns a list of stations that are displaying static text"
  def static_station_codes(pid \\ __MODULE__) do
    GenServer.call(pid, :static_station_codes)
  end

  def handle_call(:static_station_codes, _from, stations) do
    {:reply, Enum.map(stations, & &1.sign_id), stations}
  end

  def handle_info({:refresh, refresh_time}, stations) do
    schedule_refresh(refresh_time)
    station_ids = Enum.map(stations, & &1.id)
    current_time = :realtime_signs |> Application.get_env(:time_zone) |> Timex.now()
    bridge_status = Bridge.Request.get_status(@bridge_id, Timex.now())
    station_headways = station_ids
                       |> Headway.Request.get_schedules()
                       |> ScheduleHeadway.group_headways_for_stations(station_ids, current_time)

    stations
    |> Static.Messages.station_messages(refresh_time, station_headways, current_time, bridge_status)
    |> send_station_messages(current_time)
    {:noreply, stations}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  def schedule_refresh(refresh_time) do
    Process.send_after(self(), {:refresh, refresh_time}, refresh_time)
  end

  defp send_station_messages(station_messages, current_time) do
    for station_message <- station_messages do
      Logger.info("#{station_message.station} :: #{inspect station_message.messages}")
      Sign.State.request(station_message, current_time)
    end
  end
end
