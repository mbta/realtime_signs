defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  @spec valid_range?(integer(), :english | :spanish) :: boolean()
  def valid_range?(n, :english) do
    n > 0 and n < 60
  end
  def valid_range?(n, :spanish) do
    n > 0 and n < 21
  end

  @spec number_var(integer(), :english | :spanish) :: String.t | no_return()
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
  @spec time_var(integer()) :: String.t
  def time_var(n) when n > 0 and n < 60 do
    Integer.to_string(9100 + n)
  end

  def countdown_minutes_var(n) when n >= 0 and n < 30 do
    Integer.to_string(5000 + n)
  end
  def countdown_minutes_var(n) when n >= 30 do
    Integer.to_string(5030)
  end
end
