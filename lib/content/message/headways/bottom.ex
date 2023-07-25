defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range]

  @type t :: %__MODULE__{
          range: Headway.HeadwayDisplay.headway_range()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{
          range: {:first_departure, range, _first_departure}
        }) do
      Headway.HeadwayDisplay.format_headway_range(range)
    end

    def to_string(%Content.Message.Headways.Bottom{} = bottom) do
      Headway.HeadwayDisplay.format_bottom(bottom)
    end
  end
end
