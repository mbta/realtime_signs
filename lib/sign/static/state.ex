defmodule Sign.Static.State do
  use GenServer
  alias Sign.Static
  require Logger

  @default_opts [refresh_time: 250_000, stations: []]

  def start_link(user_opts \\ []) do
    opts = Keyword.merge(@default_opts, user_opts)
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    schedule_refresh(opts[:refresh_time])
    static_stations = Sign.Stations.Live.get_stations(opts[:stations])
    {:ok, static_stations}
  end

  @doc "Returns a list of stations that are displaying static text"
  def static_station_codes(pid \\ __MODULE__) do
    GenServer.call(pid, :static_station_codes)
  end

  def handle_call(:static_station_codes, _from, stations) do
    {:reply, Enum.map(stations, & &1.stop_id), stations}
  end

  def handle_info({:refresh, refresh_time}, stations) do
    schedule_refresh(refresh_time)
    station_messages = Static.Messages.station_messages(stations)
    for station_message <- station_messages do
      Logger.info("#{station_message.station} :: #{inspect station_message.messages}")
      Sign.State.request(station_message, Timex.now())
    end
    {:noreply, stations}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  def schedule_refresh(refresh_time) do
    Process.send_after(self(), {:refresh, refresh_time}, refresh_time)
  end
end
