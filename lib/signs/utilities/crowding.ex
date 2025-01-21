defmodule Signs.Utilities.Crowding do
  @spec crowding_description(Predictions.Prediction.t(), Signs.Realtime.t()) ::
          {:front | :back | :middle | :front_and_back | :train_level,
           :not_crowded | :some_crowding | :crowded | :unknown_crowding}
          | nil
  def crowding_description(_, %{source_config: {_, _}}), do: nil

  def crowding_description(%{route_id: "Orange"} = prediction, _sign) do
    case RealtimeSigns.location_engine().for_vehicle(prediction.vehicle_id) do
      %Locations.Location{
        stop_id: stop_id,
        status: status,
        multi_carriage_details: carriage_details
      }
      when stop_id == prediction.stop_id and status in [:incoming_at, :in_transit_to] ->
        get_crowding_description(carriage_details)

      _ ->
        nil
    end
  end

  def crowding_description(_, _), do: nil

  defp get_crowding_description([_, _, _, _, _, _] = carriage_details) do
    crowding_levels =
      Enum.map(carriage_details, &occupancy_percentage_to_crowding_level(&1.occupancy_percentage))

    min_crowding_level = Enum.min(crowding_levels)

    relative_crowding_levels =
      for crowding_level <- crowding_levels do
        if crowding_level == min_crowding_level,
          do: :e,
          else: :f
      end

    {get_emptier_location(
       {Enum.count(relative_crowding_levels, &Kernel.==(&1, :e)), relative_crowding_levels}
     ), crowding_level_to_atom(min_crowding_level)}
  end

  defp get_crowding_description(_), do: nil

  defp occupancy_percentage_to_crowding_level(occupancy_percentage) do
    cond do
      occupancy_percentage <= 12 -> 1
      occupancy_percentage <= 40 -> 2
      occupancy_percentage > 40 -> 3
      occupancy_percentage == nil -> 4
    end
  end

  defp crowding_level_to_atom(crowding_level) do
    case crowding_level do
      1 -> :not_crowded
      2 -> :some_crowding
      3 -> :crowded
      4 -> :unknown_crowding
    end
  end

  defp get_emptier_location(car_crowding_levels) do
    case car_crowding_levels do
      {1, [_, _, :f, :f, :f, :f]} -> :front
      {1, [:f, :f, :f, :f, _, _]} -> :back
      {1, [:f, :f, _, _, :f, :f]} -> :middle
      {2, [_, _, _, :f, :f, :f]} -> :front
      {2, [_, :f, :f, _, :f, :f]} -> :front
      {2, [:f, :f, :f, _, _, _]} -> :back
      {2, [:f, :f, _, :f, :f, _]} -> :back
      {2, [_, _, :f, :f, _, _]} -> :front_and_back
      {2, _} -> :middle
      {3, [:f, _, _, _, _, :f]} -> :middle
      {3, [_, _, _, _, :f, :f]} -> :front
      {3, [:f, :f, _, _, _, _]} -> :back
      {3, [:f, _, :f, _, :f, _]} -> :train_level
      {3, [_, :f, _, :f, _, :f]} -> :train_level
      {3, _} -> :front_and_back
      {4, [:f, _, _, _, _, :f]} -> :middle
      {4, [_, _, _, _, _, :f]} -> :front
      {4, [_, _, _, :f, :f, _]} -> :front
      {4, [:f, _, _, _, _, _]} -> :back
      {4, [_, :f, :f, _, _, _]} -> :back
      {4, [_, _, :f, :f, _, _]} -> :front_and_back
      {4, _} -> :train_level
      {5, [_, _, _, _, _, :f]} -> :front
      {5, [:f, _, _, _, _, _]} -> :back
      {5, _} -> :train_level
      {6, _} -> :train_level
      _ -> :train_level
    end
  end
end
