defmodule Sign.Canned do
  defstruct mid: nil,
    variables: [],
    type: 0,
    station: nil,
    platforms: Sign.Platforms.new,
    priority: 5,
    station_group: nil,
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    interval: nil,
    timeout: 60

  def new, do: %__MODULE__{}

  @doc """
  mid is the message to send. They are predefined in the system
  """
  def mid(state, mid), do: %{state | mid: mid}

  @doc """
  Variables are predefined strings that get interjected into the messages.
  """
  def variables(state, variables), do: %{state | variables: variables}

  def type(state, :both), do: %{state | type: 0}
  def type(state, :audio), do: %{state | type: 1}
  def type(state, :visual), do: %{state | type: 2}

  @doc """
  Stations are defined by 4 letter code (e.g. "GPRK")
  """
  def station(state, station), do: %{state | station: station}

  def platforms(state, platform, on \\ true) do
    %{state | platforms: Sign.Platforms.set(state.platforms, platform, on)}
  end

  @doc """
  Priority ranges from 2 (highest) to 7 (lowest).
  """
  def priority(state, :highest), do: %{state | priority: 2}
  def priority(state, :default), do: %{state | priority: 5}
  def priority(state, :lowest), do: %{state | priority: 7}
  def priority(state, priority), do: %{state | priority: priority}

  @doc """
  Requests need either this or a station/line/platform combo.
  """
  def station_group(state, station_group), do: %{state | station_group: station_group}

  @doc """
  Starting date for broadcasting. Defaults to today.
  """
  def start_date(state, start_date), do: %{state | start_date: start_date}

  @doc """
  Ending date to broadcasting. Defaults to today.
  """
  def end_date(state, end_date), do: %{state | end_date: end_date}

  @doc """
  Starting time to broadcast. Defaults to 1 minute from now.
  """
  def start_time(state, start_time), do: %{state | start_time: start_time}

  @doc """
  Ending time of broadcast. Defaults to 2 minutes from now.
  """
  def end_time(state, end_time), do: %{state | end_time: end_time}

  @doc """
  Repeat interval in seconds. Defaults to every 5 minutes (once, with above start/end).
  """
  def interval(state, interval) do
    interval = DateTime.from_unix!(interval)
    %{state | interval: interval}
  end

  @doc """
  When to stop the announcement if station busy. Defaults to 60s.
  """
  def timeout(state, timeout), do: %{state | timeout: timeout}

  def to_command(state) do
    [
      MsgType: "Canned",
      mid: state.mid,
      var: Enum.join(state.variables, ","),
      typ: Integer.to_string(state.type),
      sta: "#{state.station}#{Sign.Platforms.to_string(state.platforms)}",
      pri: state.priority,
      tim: state.timeout
    ]
    |> add_if_specified(:std, state.start_date, "%m%d%Y")
    |> add_if_specified(:end, state.end_date, "%m%d%Y")
    |> add_if_specified(:stt, state.start_time, "%H%M%p")
    |> add_if_specified(:ent, state.end_time, "%H%M%p")
    |> add_if_specified(:int, state.interval, "%H:%M:%S")
  end

  defp add_if_specified(command, _, nil, _), do: command
  defp add_if_specified(command, field, time, format) do
    List.insert_at(command, 1, {field, Timex.format!(time, format, :strftime)})
  end

  defimpl Sign.Command do
    def to_command(state), do: Sign.Canned.to_command(state)
  end
end
