defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  @spec number_var(integer(), :english | :spanish) :: String.t
  def number_var(n, :english) when n > 0 and n < 60 do
    Integer.to_string(5500 + n)
  end
  def number_var(n, :spanish) when n > 0 and n < 21 do
    Integer.to_string(37000 + n)
  end

  @doc "Recording of the time from 12:01 to 12:59, given the minutes"
  @spec time_var(integer()) :: String.t
  def time_var(n) when n > 0 and n < 60 do
    Integer.to_string(9100 + n)
  end

  def countdown_minutes_var(n) when n > 0 and n <= 100 do
    Integer.to_string(5000 + n)
  end
end
