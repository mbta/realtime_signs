defmodule Content.Message.Headways.Top do
  defstruct [:destination, :routes]

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          routes: [String.t()] | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Top{destination: nil, routes: ["Mattapan"]}) do
      "Mattapan trains"
    end

    def to_string(%Content.Message.Headways.Top{destination: nil, routes: [route]}) do
      "#{route} line trains"
    end

    def to_string(%Content.Message.Headways.Top{destination: nil}) do
      "Trains"
    end

    def to_string(%Content.Message.Headways.Top{destination: destination}) do
      "#{PaEss.Utilities.destination_to_sign_string(destination)} trains"
    end
  end
end
