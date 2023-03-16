defmodule Fake.ExternalConfig.Local do
  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get("unchanged") do
    :unchanged
  end

  def get("new_format") do
    {
      nil,
      %{
        "signs" => %{
          "some_custom_sign" => %{"line1" => "custom", "line2" => "", "expires" => nil}
        },
        "chelsea_bridge_announcements" => "off"
      }
    }
  end

  def get("headway_config") do
    {
      nil,
      %{
        "signs" => %{},
        "configured_headways" => %{
          "custom_headway" => %{
            "peak" => %{"range_high" => 10, "range_low" => 8}
          }
        }
      }
    }
  end

  def get(_current_version) do
    {nil,
     %{
       "chelsea_inbound" => %{"mode" => "auto"},
       "chelsea_outbound" => %{"mode" => "off"},
       "custom_text_test" => %{
         "line1" => "Test message",
         "line2" => "Please ignore",
         "expires" => "2017-07-04T12:00:00Z"
       },
       "off_test" => %{"mode" => "off"},
       "auto_test" => %{"mode" => "auto"},
       "headway_test" => %{"mode" => "headway"},
       "MVAL0" => %{"mode" => "auto"}
     }}
  end
end
