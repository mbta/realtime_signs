defmodule Engine.ScheduledHeadwaysAPI do
  @callback display_headways?([String.t()], DateTime.t(), Engine.Config.Headway.t()) :: boolean()
  @callback get_first_scheduled_departure([binary]) :: nil | DateTime.t()
end
