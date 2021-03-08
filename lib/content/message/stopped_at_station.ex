defmodule Content.Message.StoppedAtStation do
  require Logger

  @stations_by_stop_id %{
    "70036" => :oak_grove,
    "70034" => :malden_center,
    "70035" => :malden_center,
    "70032" => :wellington,
    "70033" => :wellington,
    "70278" => :assembly,
    "70279" => :assembly,
    "70030" => :sullivan_square,
    "70031" => :sullivan_square,
    "70028" => :community_college,
    "70029" => :community_college,
    "70026" => :north_station,
    "70027" => :north_station,
    "70024" => :haymarket,
    "70025" => :haymarket,
    "70022" => :state,
    "70023" => :state,
    "70020" => :downtown_crossing,
    "70021" => :downtown_crossing,
    "70018" => :chinatown,
    "70019" => :chinatown,
    "70016" => :tufts_medical_center,
    "70017" => :tufts_medical_center,
    "70014" => :back_bay,
    "70015" => :back_bay,
    "70012" => :massachusetts_avenue,
    "70013" => :massachusetts_avenue,
    "70010" => :ruggles,
    "70011" => :ruggles,
    "70008" => :roxbury_crossing,
    "70009" => :roxbury_crossing,
    "70006" => :jackson_square,
    "70007" => :jackson_square,
    "70004" => :stony_brook,
    "70005" => :stony_brook,
    "70002" => :green_street,
    "70003" => :green_street,
    "70001" => :forest_hills
  }

  @stations_in_order [
    :oak_grove,
    :malden_center,
    :wellington,
    :assembly,
    :sullivan_square,
    :community_college,
    :north_station,
    :haymarket,
    :state,
    :downtown_crossing,
    :chinatown,
    :tufts_medical_center,
    :back_bay,
    :massachusetts_avenue,
    :ruggles,
    :roxbury_crossing,
    :jackson_square,
    :stony_brook,
    :green_street,
    :forest_hills,
    :green_street,
    :stony_brook,
    :jackson_square,
    :roxbury_crossing,
    :ruggles,
    :massachusetts_avenue,
    :back_bay,
    :tufts_medical_center,
    :chinatown,
    :downtown_crossing,
    :state,
    :haymarket,
    :north_station,
    :community_college,
    :sullivan_square,
    :assembly,
    :wellington,
    :malden_center,
    :oak_grove
  ]
  defstruct [:destination, :stopped_at]

  @type t :: %__MODULE__{
          destination: atom(),
          stopped_at: atom()
        }

  @spec from_prediction(Predictions.Prediction.t()) :: t() | nil
  def from_prediction(prediction) do
    case Content.Utilities.destination_for_prediction(
           prediction.route_id,
           prediction.direction_id,
           prediction.destination_stop_id
         ) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
          stopped_at: get_train_location(prediction, destination)
        }

      {:error, _} ->
        Logger.warn("StoppedAtStation no_destination_for_prediction #{inspect(prediction)}")
        nil
    end
  end

  defimpl Content.Message do
    def to_string(stopped_at_station) do
      [
        {"#{PaEss.Utilities.destination_to_sign_string(stopped_at_station.destination)} waiting ",
         6},
        {"at #{stop_atom_to_string(stopped_at_station.stopped_at)}     ", 3}
      ]
    end

    @spec stop_atom_to_string(atom()) :: String.t()
    def stop_atom_to_string(:oak_grove), do: "Oak Grove"
    def stop_atom_to_string(:malden_center), do: "Malden Ctr"
    def stop_atom_to_string(:wellington), do: "Wellington"
    def stop_atom_to_string(:assembly), do: "Assembly"
    def stop_atom_to_string(:sullivan_square), do: "Sullivan Sq"
    def stop_atom_to_string(:community_college), do: "Community Col"
    def stop_atom_to_string(:north_station), do: "North Station"
    def stop_atom_to_string(:haymarket), do: "Haymarket"
    def stop_atom_to_string(:state), do: "State"
    def stop_atom_to_string(:downtown_crossing), do: "Downtown Xing"
    def stop_atom_to_string(:chinatown), do: "Chinatown"
    def stop_atom_to_string(:tufts_medical_center), do: "Tufts Med Ctr"
    def stop_atom_to_string(:back_bay), do: "Back Bay"
    def stop_atom_to_string(:massachusetts_avenue), do: "Mass Ave"
    def stop_atom_to_string(:ruggles), do: "Ruggles"
    def stop_atom_to_string(:roxbury_crossing), do: "Roxbury Xing"
    def stop_atom_to_string(:jackson_square), do: "Jackson Sq"
    def stop_atom_to_string(:stony_brook), do: "Stony Brook"
    def stop_atom_to_string(:green_street), do: "Green St"
    def stop_atom_to_string(:forest_hills), do: "Frst Hills"
  end

  @spec get_train_location(
          Predictions.Prediction.t(),
          :forest_hills | :oak_grove
        ) :: atom()
  def get_train_location(prediction, destination) do
    this_station = @stations_by_stop_id[prediction.stop_id]
    this_station_index = Enum.find_index(@stations_in_order, fn x -> x == this_station end)
    num_stops_away = prediction.stops_away

    case destination do
      :oak_grove ->
        Enum.at(@stations_in_order, this_station_index + num_stops_away)

      :forest_hills ->
        Enum.at(@stations_in_order, abs(this_station_index - num_stops_away))
    end
  end
end
