defmodule Content.Message.Predictions do
  @moduledoc """
  A message related to real time predictions. For example:

  Mattapan    BRD
  Mattapan    ARR
  Mattapan  2 min

  The constructor should be used rather than creating a struct
  yourself.
  """

  @enforce_keys [:headsign, :minutes]
  defstruct [:headsign, :minutes, width: 18]

  @type t :: %__MODULE__{
    headsign: String.t(),
    minutes: integer() | :boarding | :arriving,
    width: integer(),
  }

  @spec new(Predictions.Prediction.t(), String.t()) :: t()
  def new(%Predictions.Prediction{} = prediction, headsign, width \\ 18) do
    minutes = case prediction.seconds_until_arrival do
      0 -> :boarding
      x when x in 1..30 -> :arriving
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

    def to_string(%{headsign: headsign, minutes: :boarding, width: width}) do
      build_string(headsign, @boarding, width)
    end

    def to_string(%{headsign: headsign, minutes: :arriving, width: width}) do
      build_string(headsign, @arriving, width)
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
