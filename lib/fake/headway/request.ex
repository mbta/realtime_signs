defmodule Fake.Headway.Request do
  @times [
    ~N[2017-07-04 09:05:00],
    ~N[2017-07-04 08:55:00],
    ~N[2017-07-04 08:45:00],
    ~N[2017-07-04 09:20:00]
  ]

  def get_schedules(stop_list) do
    Enum.flat_map(stop_list, fn stop_id ->
      Enum.map(@times, fn time ->
        %{
          "relationships" => %{
            "prediction" => %{},
            "route" => %{"data" => %{"id" => "743", "type" => "route"}},
            "stop" => %{"data" => %{"id" => stop_id, "type" => "stop"}},
            "trip" => %{"data" => %{"id" => "36684269", "type" => "trip"}}
          },
          "attributes" => %{
            "arrival_time" =>
              Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}"),
            "departure_time" =>
              Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
          }
        }
      end)
    end)
  end
end
