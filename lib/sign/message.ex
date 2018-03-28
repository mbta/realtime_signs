defmodule Sign.Message do

  @ashmont_gtfs_id "70262"

  defstruct message: [],
    placement: [],
    when: nil,
    duration: nil

  @type t :: %__MODULE__{
    message: [{String.t, String.t | nil}],
    when: integer | nil,
    duration: integer | nil
  }

  def new, do: %__MODULE__{}

  @doc """
  Send a new message. Takes an integer :duration option for how long to display this
  message, in seconds.
  """
  def message(state, string, options \\ [])
  def message(state, :blank, options) do
    message(state, String.duplicate(" ", Sign.Content.sign_width()), options)
  end
  def message(state, string, options) do
    %{state | message: [{string, options[:duration]} | state.message]}
  end

  @doc """
  Where to place the message. The sign can be :eastbound, :westbound, etc, :center,
  or :mezzanine. The line should either be :top or :bottom.
  """
  def placement(state, sign, line) do
    location = "#{sign_code(sign)}#{line_code(line)}"
    %{state | placement: [location | state.placement]}
  end

  @doc """
  When to display the message. If not specified the message will be displayed now.
  """
  def at_time(state, time = %DateTime{}) do
    %{state | when: Timex.diff(time, Timex.beginning_of_day(time), :seconds)}
  end
  def at_time(state, seconds_since_midnight) do
    %{state | when: seconds_since_midnight}
  end

  @doc """
  How long to display the entire message, in seconds.
  """
  def erase_after(state, seconds) do
    %{state | duration: seconds}
  end

  def sign_code(:eastbound), do: "e"
  def sign_code(:westbound), do: "w"
  def sign_code(:northbound), do: "n"
  def sign_code(:southbound), do: "s"
  def sign_code(:mezzanine), do: "m"
  def sign_code(:center), do: "c"

  def line_code(line) when is_integer(line), do: Integer.to_string(line)
  def line_code(:top), do: "1"
  def line_code(:bottom), do: "2"

  defp time_string(nil), do: ""
  defp time_string(seconds_since_midnight), do: "t#{seconds_since_midnight}"

  defp duration_string(nil), do: ""
  defp duration_string(duration), do: "e#{duration}"

  defp placements_string(placements) do
    placements
    |> Enum.map(&("~" <> &1))
    |> Enum.reverse
    |> Enum.join
  end

  defp messages_string(messages) do
    messages
    |> Enum.map(&message_string/1)
    |> Enum.map(&("-" <> &1))
    |> Enum.reverse
    |> Enum.join
  end

  defp message_string({message, duration}) when is_atom(message) do
    "#{message}#{message_duration(duration)}"
  end
  defp message_string({message, duration}) when is_binary(message) do
    "\"#{message}\"#{message_duration(duration)}"
  end

  defp message_duration(nil), do: ""
  defp message_duration(duration), do: ".#{duration}"

  def to_string(state) do
    time = time_string(state.when)
    duration = duration_string(state.duration)
    placements = placements_string(state.placement)
    messages = messages_string(state.message)

    "#{time}#{duration}#{placements}#{messages}"
  end

  @doc "Provides the headsign to be used in a message"
  @spec headsign(integer, String.t, String.t) :: String.t
  def headsign(0, "Mattapan", _), do: "Mattapan"
  def headsign(1, "Mattapan", @ashmont_gtfs_id), do: "Mattapan" # Special case for Ashmont since it's a terminal
  def headsign(1, "Mattapan", _), do: "Ashmont"
  def headsign(1, "743", _), do: "Chelsea"
  def headsign(0, "743", _), do: "South Sta."

  @doc "Providesthe correct vehicle name for the given route id"
  @spec vehicle_name(String.t) :: String.t
  def vehicle_name("Mattapan"), do: "Trolley"
  def vehicle_name("743"), do: "Buses"
end
