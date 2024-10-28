defmodule Engine.Config.Headway do
  @enforce_keys [:headway_id, :range_high, :range_low]
  defstruct @enforce_keys

  @type headway_group :: String.t()
  @type time_period :: :weekday | :saturday | :sunday
  @type headway_id :: {headway_group(), time_period()}

  @type t :: %__MODULE__{
          headway_id: headway_id(),
          range_high: integer(),
          range_low: integer()
        }

  @spec current_time_period(DateTime.t()) :: time_period()
  def current_time_period(dt) do
    # Subtract 3 hours, since the service day ends at 3 AM
    case DateTime.add(dt, -3, :hour) |> Date.day_of_week() do
      6 -> :saturday
      7 -> :sunday
      _ -> :weekday
    end
  end
end
