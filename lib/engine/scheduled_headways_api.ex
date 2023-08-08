defmodule Engine.ScheduledHeadwaysAPI do
  @callback display_headways?([String.t()], DateTime.t(), non_neg_integer()) :: boolean()
end
