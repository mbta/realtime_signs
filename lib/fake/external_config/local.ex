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
        }
      }
    }
  end

  def get("headway_config") do
    {
      nil,
      %{
        "signs" => %{},
        "multi_sign_headways" => %{
          "custom_headway" => %{"range_high" => 10, "range_low" => 8}
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
