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
  defstruct [:headsign, :minutes]

  @type t :: %__MODULE__{
    headsign: String.t(),
    minutes: integer() | :boarding | :arriving
  }

  @spec new(Predictions.Prediction.t(), String.t()) :: t()
  def new(%Predictions.Prediction{} = prediction, headsign) do
    minutes = case prediction.seconds_until_arrival do
      0 -> :boarding
      x when x in 1..60 -> :arriving
      x -> div(x, 60)
    end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
    }
  end

  defimpl Content.Message, for: Content.Message.Predictions   do
    require Logger

    @width 18
    @boarding "BRD"
    @arriving "ARR"

    def to_string(%{headsign: headsign, minutes: :boarding}) do
      build_string(headsign, @boarding)
    end

    def to_string(%{headsign: headsign, minutes: :arriving}) do
      build_string(headsign, @arriving)
    end

    def to_string(%{headsign: headsign, minutes: n}) when n > 0 and n < 1000 do
      build_string(headsign, "#{n} min")
    end

    def to_string(e) do
      Logger.error("cannot_to_string: #{inspect(e)}")
      ""
    end

    defp build_string(left, right) do
      max_left_length = @width - (String.length(right) + 2)
      left = String.slice(left, 0, max_left_length)
      padding = @width - (String.length(left) + String.length(right))
      Enum.join([left, String.duplicate(" ", padding), right])
    end
  end
end
