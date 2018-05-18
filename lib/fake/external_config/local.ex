defmodule Fake.ExternalConfig.Local do
 def get("unchanged") do
   :unchanged
 end
 def get(_current_version) do
   {nil, %{"chelsea_inbound" => %{"enabled" => true},
    "chelsea_outbound" => %{"enabled" => false},
    "MVAL0" => %{"enabled" => false}
    }}
 end

end
