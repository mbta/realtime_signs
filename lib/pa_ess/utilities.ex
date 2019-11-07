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

  @spec valid_destination?(PaEss.destination(), Content.Audio.language()) :: boolean()
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
  @spec destination_var(PaEss.destination()) :: {:ok, String.t()} | {:error, :unknown}
  def destination_var(:alewife), do: {:ok, "4000"}
  def destination_var(:ashmont), do: {:ok, "4016"}
  def destination_var(:boston_college), do: {:ok, "4202"}
  def destination_var(:bowdoin), do: {:ok, "4055"}
  def destination_var(:braintree), do: {:ok, "4021"}
  def destination_var(:cleveland_circle), do: {:ok, "4203"}
  def destination_var(:forest_hills), do: {:ok, "4043"}
  def destination_var(:government_center), do: {:ok, "4061"}
  def destination_var(:heath_street), do: {:ok, "4204"}
  def destination_var(:kenmore), do: {:ok, "4070"}
  def destination_var(:lechmere), do: {:ok, "4056"}
  def destination_var(:mattapan), do: {:ok, "4100"}
  def destination_var(:north_station), do: {:ok, "4027"}
  def destination_var(:oak_grove), do: {:ok, "4022"}
  def destination_var(:park_street), do: {:ok, "4007"}
  def destination_var(:reservoir), do: {:ok, "4076"}
  def destination_var(:riverside), do: {:ok, "4084"}
  def destination_var(:wonderland), do: {:ok, "4044"}
  def destination_var(_), do: {:error, :unknown}

  @spec headsign_to_destination(String.t()) :: {:ok, PaEss.destination()} | {:error, :unknown}
  def headsign_to_destination("Alewife"), do: {:ok, :alewife}
  def headsign_to_destination("Ashmont"), do: {:ok, :ashmont}
  def headsign_to_destination("Boston Col"), do: {:ok, :boston_college}
  def headsign_to_destination("Boston College"), do: {:ok, :boston_college}
  def headsign_to_destination("Bowdoin"), do: {:ok, :bowdoin}
  def headsign_to_destination("Braintree"), do: {:ok, :braintree}
  def headsign_to_destination("Chelsea"), do: {:ok, :chelsea}
  def headsign_to_destination("Cleveland Circle"), do: {:ok, :cleveland_circle}
  def headsign_to_destination("Clvlnd Cir"), do: {:ok, :cleveland_circle}
  def headsign_to_destination("Eastbound"), do: {:ok, :eastbound}
  def headsign_to_destination("Frst Hills"), do: {:ok, :forest_hills}
  def headsign_to_destination("Govt Ctr"), do: {:ok, :government_center}
  def headsign_to_destination("Heath St"), do: {:ok, :heath_street}
  def headsign_to_destination("Kenmore"), do: {:ok, :kenmore}
  def headsign_to_destination("Lechmere"), do: {:ok, :lechmere}
  def headsign_to_destination("Mattapan"), do: {:ok, :mattapan}
  def headsign_to_destination("North Sta"), do: {:ok, :north_station}
  def headsign_to_destination("North Station"), do: {:ok, :north_station}
  def headsign_to_destination("Northbound"), do: {:ok, :northbound}
  def headsign_to_destination("Oak Grove"), do: {:ok, :oak_grove}
  def headsign_to_destination("Park St"), do: {:ok, :park_street}
  def headsign_to_destination("Park Street"), do: {:ok, :park_street}
  def headsign_to_destination("Reservoir"), do: {:ok, :reservoir}
  def headsign_to_destination("Riverside"), do: {:ok, :riverside}
  def headsign_to_destination("South Station"), do: {:ok, :south_station}
  def headsign_to_destination("Southbound"), do: {:ok, :southbound}
  def headsign_to_destination("Westbound"), do: {:ok, :westbound}
  def headsign_to_destination("Wonderland"), do: {:ok, :wonderland}
  def headsign_to_destination(_unknown), do: {:error, :unknown}
end
