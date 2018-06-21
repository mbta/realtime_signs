defmodule Content.Message.Predictions do
  @moduledoc """
  A message related to real time predictions. For example:

  Mattapan    BRD
  Mattapan    ARR
  Mattapan  2 min

  The constructor should be used rather than creating a struct
  yourself.
  """

  @thirty_minutes 30 * 60

  @enforce_keys [:headsign, :minutes]
  defstruct [:headsign, :minutes, width: 18]

  @type t :: %__MODULE__{
    headsign: String.t(),
    minutes: integer() | :boarding | :arriving | :thirty_plus,
    width: integer(),
  }

  @spec non_terminal(Predictions.Prediction.t(), String.t(), boolean) :: t()
  def non_terminal(%Predictions.Prediction{} = prediction, headsign, width \\ 18, stopped_at?) do
    minutes = cond do
      stopped_at? -> :boarding
      prediction.seconds_until_arrival <= 30 -> :arriving
      prediction.seconds_until_arrival >= @thirty_minutes -> :thirty_plus
      true -> prediction.seconds_until_arrival |> Kernel./(60) |> round()
    end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
      width: width,
    }
  end

  @spec terminal(Predictions.Prediction.t(), String.t(), boolean()) :: t()
  def terminal(%Predictions.Prediction{} = prediction, headsign, width \\ 18, stopped_at?) do
    minutes = case prediction.seconds_until_arrival do
      x when x <= 30 and stopped_at? -> :boarding
      x when x <= 30 -> 1
      x when x >= @thirty_minutes -> :thirty_plus
      x -> x |> Kernel./(60) |> round()
    end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
      width: width,
    }
  end

  defimpl Content.Message do
    require Logger

    @boarding "BRD"
    @arriving "ARR"
    @thirty_plus "30+ min"

    def to_string(%{headsign: headsign, minutes: :boarding, width: width}) do
      build_string(headsign, @boarding, width)
    end

    def to_string(%{headsign: headsign, minutes: :arriving, width: width}) do
      build_string(headsign, @arriving, width)
    end

    def to_string(%{headsign: headsign, minutes: :thirty_plus, width: width}) do
      build_string(headsign, @thirty_plus, width)
    end

    def to_string(%{headsign: headsign, minutes: n, width: width}) when n > 0 and n < 1000 do
      build_string(headsign, "#{n} min", width)
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end

    defp build_string(left, right, width) do
      max_left_length = width - (String.length(right) + 2)
      left = String.slice(left, 0, max_left_length)
      padding = width - (String.length(left) + String.length(right))
      Enum.join([left, String.duplicate(" ", padding), right])
    end
  end
end
