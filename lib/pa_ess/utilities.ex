defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  require Logger

  @spec valid_range?(integer(), :english | :spanish) :: boolean()
  def valid_range?(n, :english) do
    n > 0 and n < 60
  end

  def valid_range?(n, :spanish) do
    n > 0 and n < 21
  end

  @spec number_var(integer(), :english | :spanish) :: String.t() | no_return()
  def number_var(n, :english) do
    cond do
      valid_range?(n, :english) -> Integer.to_string(5500 + n)
    end
  end

  def number_var(n, :spanish) do
    cond do
      valid_range?(n, :spanish) -> Integer.to_string(37000 + n)
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
  @spec take_message_id([integer()]) :: integer()
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

  @spec headsign_to_terminal_station(String.t()) :: {:ok, PaEss.terminal_station()} | {:error, :unknown}
  def headsign_to_terminal_station("Ashmont"), do: {:ok, :ashmont}
  def headsign_to_terminal_station("Mattapan"), do: {:ok, :mattapan}
  def headsign_to_terminal_station("Bowdoin"), do: {:ok, :bowdoin}
  def headsign_to_terminal_station("Wonderland"), do: {:ok, :wonderland}
  def headsign_to_terminal_station("Frst Hills"), do: {:ok, :forest_hills}
  def headsign_to_terminal_station("Oak Grove"), do: {:ok, :oak_grove}
  def headsign_to_terminal_station("Braintree"), do: {:ok, :braintree}
  def headsign_to_terminal_station("Alewife"), do: {:ok, :alewife}
  def headsign_to_terminal_station(_unknown), do: {:error, :unknown}
end
