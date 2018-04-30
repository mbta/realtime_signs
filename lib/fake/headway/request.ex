defmodule Fake.Headway.Request do

  @times [
    ~N[2017-07-04 09:05:00],
    ~N[2017-07-04 08:55:00],
    ~N[2017-07-04 08:45:00],
    ~N[2017-07-04 09:20:00]
  ]

  def get_schedules(["123"]) do
    Enum.map(@times, fn time ->
      %{"relationships" => %{"stop" => %{"data" => %{"id" => "123"}}},
        "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
    end)
  end
end
