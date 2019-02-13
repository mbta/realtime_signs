defmodule Content.Utilities do
  def width_padded_string(left, right, width) do
    max_left_length = width - (String.length(right) + 1)
    left = String.slice(left, 0, max_left_length)
    padding = width - (String.length(left) + String.length(right))
    Enum.join([left, String.duplicate(" ", padding), right])
  end

  @spec headsign_for_prediction(String.t(), 0 | 1, String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def headsign_for_prediction("Mattapan", 0, _), do: {:ok, "Mattapan"}
  def headsign_for_prediction("Mattapan", 1, _), do: {:ok, "Ashmont"}
  def headsign_for_prediction("Orange", 0, _), do: {:ok, "Frst Hills"}
  def headsign_for_prediction("Orange", 1, _), do: {:ok, "Oak Grove"}
  def headsign_for_prediction("Blue", 0, _), do: {:ok, "Bowdoin"}
  def headsign_for_prediction("Blue", 1, _), do: {:ok, "Wonderland"}
  def headsign_for_prediction("Red", 1, _), do: {:ok, "Alewife"}

  def headsign_for_prediction("Red", 0, last_stop_id)
      when last_stop_id in ["70085", "70086", "70087", "70089", "70091", "70093"],
      do: {:ok, "Ashmont"}

  def headsign_for_prediction("Red", 0, "Braintree-" <> _), do: {:ok, "Braintree"}

  def headsign_for_prediction("Red", 0, last_stop_id)
      when last_stop_id in ["70095", "70096", "70097", "70101", "70103", "70105"],
      do: {:ok, "Braintree"}

  def headsign_for_prediction(_, 0, "70149"), do: {:ok, "Kenmore"}
  def headsign_for_prediction(_, 0, "70151"), do: {:ok, "Kenmore"}
  def headsign_for_prediction(_, 0, "70202"), do: {:ok, "Govt Ctr"}
  def headsign_for_prediction(_, 0, "70201"), do: {:ok, "Govt Ctr"}
  def headsign_for_prediction(_, 0, "70175"), do: {:ok, "Reservoir"}
  def headsign_for_prediction(_, 0, "70107"), do: {:ok, "Boston Col"}
  def headsign_for_prediction(_, 0, "70237"), do: {:ok, "Clvlnd Cir"}
  def headsign_for_prediction(_, 0, "70161"), do: {:ok, "Riverside"}
  def headsign_for_prediction(_, 0, "70260"), do: {:ok, "Heath St"}

  def headsign_for_prediction(_, 1, "70209"), do: {:ok, "Lechmere"}
  def headsign_for_prediction(_, 1, "70205"), do: {:ok, "North Sta"}
  def headsign_for_prediction(_, 1, "70201"), do: {:ok, "Govt Ctr"}
  def headsign_for_prediction(_, 1, "70200"), do: {:ok, "Park St"}
  def headsign_for_prediction(_, 1, "70150"), do: {:ok, "Kenmore"}
  def headsign_for_prediction(_, 1, "70174"), do: {:ok, "Reservoir"}

  def headsign_for_prediction("Green-B", 0, _), do: {:ok, "Boston Col"}
  def headsign_for_prediction("Green-C", 0, _), do: {:ok, "Clvlnd Cir"}
  def headsign_for_prediction("Green-D", 0, _), do: {:ok, "Riverside"}
  def headsign_for_prediction("Green-E", 0, _), do: {:ok, "Heath St"}
  def headsign_for_prediction("Green-B", 1, _), do: {:ok, "Park St"}
  def headsign_for_prediction("Green-C", 1, _), do: {:ok, "North Sta"}
  def headsign_for_prediction("Green-D", 1, _), do: {:ok, "Govt Ctr"}
  def headsign_for_prediction("Green-E", 1, _), do: {:ok, "Lechmere"}

  def headsign_for_prediction(_, _, _), do: {:error, :not_found}
end
