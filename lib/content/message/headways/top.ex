defmodule Content.Message.Headways.Top do
  require Logger
  defstruct [:destination, :vehicle_type]

  @type vehicle_type :: :bus | :trolley | :train
  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          vehicle_type: vehicle_type
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Top{
          destination: nil,
          vehicle_type: type
        }) do
      type |> signify_vehicle_type |> String.capitalize()
    end

    def to_string(%Content.Message.Headways.Top{
          destination: destination,
          vehicle_type: type
        })
        when type in [:bus] do
      "#{type |> signify_vehicle_type() |> String.capitalize()} to #{
        PaEss.Utilities.destination_to_sign_string(destination)
      }"
    end

    def to_string(%Content.Message.Headways.Top{
          destination: destination,
          vehicle_type: type
        }) do
      message =
        "#{PaEss.Utilities.destination_to_sign_string(destination)} #{signify_vehicle_type(type)}"

      Logger.info("Headway top message: #{IO.puts(message)}")
      message
    end

    @spec signify_vehicle_type(Content.Message.Headways.Top.vehicle_type()) :: String.t()
    defp signify_vehicle_type(:train) do
      "trains"
    end

    defp signify_vehicle_type(:bus) do
      "buses"
    end

    defp signify_vehicle_type(:trolley) do
      "trolleys"
    end
  end
end
