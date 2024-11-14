defmodule Content.Message.Headways.Top do
  defstruct [:destination, :route]

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          route: String.t() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Top{destination: nil, route: nil}) do
      "Trains"
    end

    def to_string(%Content.Message.Headways.Top{destination: nil, route: "Mattapan"}) do
      "Mattapan trains"
    end

    def to_string(%Content.Message.Headways.Top{destination: nil, route: route}) do
      "#{route} line trains"
    end

    def to_string(%Content.Message.Headways.Top{destination: destination}) do
      "#{PaEss.Utilities.destination_to_sign_string(destination)} trains"
    end
  end
end
