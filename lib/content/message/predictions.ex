defmodule Content.Message.Predictions do
  @moduledoc """
  A message related to real time predictions. For example:

  Mattapan    BRD
  Mattapan    ARR
  Mattapan  2 min

  The constructor should be used rather than creating a struct
  yourself.
  """

  require Logger

  @thirty_one_minutes 31 * 60

  @enforce_keys [:headsign, :minutes]
  defstruct [:headsign, :minutes, width: 18]

  @type t :: %__MODULE__{
    headsign: String.t(),
    minutes: integer() | :boarding | :arriving | :thirty_plus,
    width: integer(),
  }

  @spec non_terminal(Predictions.Prediction.t(), boolean) :: t()
  def non_terminal(%Predictions.Prediction{destination_stop_id: destination_stop_id} = prediction, width \\ 18, stopped_at?) do
    minutes = cond do
      stopped_at? -> :boarding
      prediction.seconds_until_arrival <= 30 -> :arriving
      prediction.seconds_until_arrival >= @thirty_one_minutes -> :thirty_plus
      true -> prediction.seconds_until_arrival |> Kernel./(60) |> round()
    end

    headsign = case headsign_for_prediction(prediction.route_id, prediction.direction_id, prediction.destination_stop_id) do
      {:ok, dest} ->
        dest
      {:error, _} ->
        Logger.warn "Could not find hedasign for prediction #{inspect prediction}"
        ""
    end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
      width: width,
    }
  end

  @spec terminal(Predictions.Prediction.t(), boolean()) :: t()
  def terminal(%Predictions.Prediction{destination_stop_id: destination_stop_id} = prediction, width \\ 18, stopped_at?) do
    minutes = case prediction.seconds_until_departure do
      x when x <= 30 and stopped_at? -> :boarding
      x when x <= 30 -> 1
      x when x >= @thirty_one_minutes -> :thirty_plus
      x -> x |> Kernel./(60) |> round()
    end

    headsign = case headsign_for_prediction(prediction.route_id, prediction.direction_id, prediction.destination_stop_id) do
      {:ok, dest} ->
        dest
      {:error, _} ->
        Logger.warn "Could not find hedasign for prediction #{inspect prediction}"
        ""
    end

    %__MODULE__{
      headsign: headsign,
      minutes: minutes,
      width: width,
    }
  end

  @spec headsign_for_prediction(String.t(), 0 | 1, String.t()) :: {:ok, String.t()} | {:error, :not_found}
  defp headsign_for_prediction("Mattapan", 0, _), do: {:ok, "Mattapan"}
  defp headsign_for_prediction("Mattapan", 1, _), do: {:ok, "Ashmont"}
  defp headsign_for_prediction("Orange", 0, _), do: {:ok, "Frst Hills"}
  defp headsign_for_prediction("Orange", 1, _), do: {:ok, "Oak Grove"}
  defp headsign_for_prediction("Blue", 0, _), do: {:ok, "Bowdoin"}
  defp headsign_for_prediction("Blue", 1, _), do: {:ok, "Wonderland"}
  defp headsign_for_prediction("Red", 1, _), do: {:ok, "Alewife"}
  defp headsign_for_prediction("Red", 0, last_stop_id) when last_stop_id in ["70087", "70089", "70091", "70093"], do: {:ok, "Ashmont"}
  defp headsign_for_prediction("Red", 0, last_stop_id) when last_stop_id in ["70097", "70101", "70103", "70105"], do: {:ok, "Braintree"}
  defp headsign_for_prediction("Green-B", 0, _), do: {:ok, "Boston Col"}
  defp headsign_for_prediction("Green-C", 0, _), do: {:ok, "Clvlnd Cir"}
  defp headsign_for_prediction("Green-D", 0, _), do: {:ok, "Riverside"}
  defp headsign_for_prediction("Green-E", 0, _), do: {:ok, "Heath St"}
  defp headsign_for_prediction(_, 1, "70209"), do: {:ok, "Lechmere"}
  defp headsign_for_prediction(_, 1, "70205"), do: {:ok, "North Sta"}
  defp headsign_for_prediction(_, 1, "70201"), do: {:ok, "Govt Ctr"}
  defp headsign_for_prediction(_, 1, "70200"), do: {:ok, "Park St"}
  defp headsign_for_prediction(_, _, _), do: {:error, :not_found}

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
