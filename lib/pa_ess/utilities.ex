defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  require Logger

  @spec valid_range?(integer(), Content.Audio.language()) :: boolean()
  def valid_range?(n, :english) do
    n > 0 and n < 60
  end

  def valid_range?(n, :spanish) do
    n > 0 and n < 21
  end

  @spec valid_destination?(Content.Audio.destination(), Content.Audio.language()) :: boolean()
  def valid_destination?(destination, language) when not is_nil(destination) do
    language == :english or destination in [:chelsea, :south_station]
  end

  @spec number_var(integer(), Content.Audio.language()) :: String.t() | nil
  def number_var(n, :english) do
    if valid_range?(n, :english) do
      Integer.to_string(5500 + n)
    else
      nil
    end
  end

  def number_var(n, :spanish) do
    if valid_range?(n, :spanish) do
      Integer.to_string(37000 + n)
    else
      nil
    end
  end

  @doc "Recording of the time from 12:01 to 12:59, given the minutes"
  @spec time_var(integer()) :: String.t()
  def time_var(n) when n > 0 and n < 60 do
    Integer.to_string(9100 + n)
  end

  def countdown_minutes_var(n) when n >= 0 and n < 30 do
    Integer.to_string(5000 + n)
  end

  def countdown_minutes_var(n) when n >= 30 do
    Integer.to_string(5030)
  end

  @doc "Message ID for a dynamic message constructed from TAKE variables"
  @spec take_message_id([String.t()]) :: String.t()
  def take_message_id(vars) do
    Integer.to_string(102 + length(vars))
  end

  @doc "Take ID for terminal destinations"
  @spec destination_var(PaEss.terminal_station()) :: String.t()
  def destination_var(:ashmont), do: "4016"
  def destination_var(:mattapan), do: "4100"
  def destination_var(:bowdoin), do: "4055"
  def destination_var(:wonderland), do: "4044"
  def destination_var(:forest_hills), do: "4043"
  def destination_var(:oak_grove), do: "4022"
  def destination_var(:braintree), do: "4021"
  def destination_var(:alewife), do: "4000"
  def destination_var(:boston_college), do: "4202"
  def destination_var(:cleveland_circle), do: "4203"
  def destination_var(:riverside), do: "4084"
  def destination_var(:heath_st), do: "4204"
  def destination_var(:reservoir), do: "4076"
  def destination_var(:lechmere), do: "4056"
  def destination_var(:north_station), do: "4027"
  def destination_var(:government_center), do: "4061"
  def destination_var(:park_st), do: "4007"
  def destination_var(:kenmore), do: "4070"

  @spec headsign_to_terminal_station(String.t()) ::
          {:ok, PaEss.terminal_station()} | {:error, :unknown}
  def headsign_to_terminal_station("Ashmont"), do: {:ok, :ashmont}
  def headsign_to_terminal_station("Mattapan"), do: {:ok, :mattapan}
  def headsign_to_terminal_station("Bowdoin"), do: {:ok, :bowdoin}
  def headsign_to_terminal_station("Wonderland"), do: {:ok, :wonderland}
  def headsign_to_terminal_station("Frst Hills"), do: {:ok, :forest_hills}
  def headsign_to_terminal_station("Oak Grove"), do: {:ok, :oak_grove}
  def headsign_to_terminal_station("Braintree"), do: {:ok, :braintree}
  def headsign_to_terminal_station("Alewife"), do: {:ok, :alewife}
  def headsign_to_terminal_station("Boston Col"), do: {:ok, :boston_college}
  def headsign_to_terminal_station("Clvlnd Cir"), do: {:ok, :cleveland_circle}
  def headsign_to_terminal_station("Riverside"), do: {:ok, :riverside}
  def headsign_to_terminal_station("Heath St"), do: {:ok, :heath_st}
  def headsign_to_terminal_station("Reservoir"), do: {:ok, :reservoir}
  def headsign_to_terminal_station("Lechmere"), do: {:ok, :lechmere}
  def headsign_to_terminal_station("North Sta"), do: {:ok, :north_station}
  def headsign_to_terminal_station("Govt Ctr"), do: {:ok, :government_center}
  def headsign_to_terminal_station("Park St"), do: {:ok, :park_st}
  def headsign_to_terminal_station("Kenmore"), do: {:ok, :kenmore}
  def headsign_to_terminal_station(_unknown), do: {:error, :unknown}

  @doc "Wrapper for headsign_to_terminal_station/1 that also handles :southbound"
  @spec headsign_to_destination(String.t()) :: PaEss.destination() | nil
  def headsign_to_destination("Southbound") do
    :southbound
  end

  def headsign_to_destination(headsign) do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, headsign} -> headsign
      _ -> nil
    end
  end
end
