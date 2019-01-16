defmodule Fake.ExternalConfig.Local do
  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get("unchanged") do
    :unchanged
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
       "MVAL0" => %{"enabled" => false}
     }}
  end
end
