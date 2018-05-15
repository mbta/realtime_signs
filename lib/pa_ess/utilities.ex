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

  @spec number_var(integer(), :english | :spanish) :: {:ok, String.t} | {:error, :invalid}
  def number_var(n, :english) do
    if valid_range?(n, :english) do
      {:ok, Integer.to_string(5500 + n)}
    else
      {:error, :invalid}
    end
  end
  def number_var(n, :spanish) do
    if valid_range?(n, :spanish) do
      {:ok, Integer.to_string(37000 + n)}
    else
      {:error, :invalid}
    end
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
