defmodule Test.Support.Generators do
  import StreamData

  @spec gen_headway_range() :: StreamData.t(Headway.HeadwayDisplay.headway_range())
  def gen_headway_range do
    one_of([
      tuple({positive_integer(), positive_integer()}) |> map(fn {x, y} -> {x, x + y} end),
      tuple({constant(:up_to), positive_integer()}),
      constant(:none)
    ])
  end
end
