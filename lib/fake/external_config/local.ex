defmodule Fake.ExternalConfig.Local do
 def get() do
   %{"chelsea_inbound" => %{"enabled" => true},
    "chelsea_outbound" => %{"enabled" => false},
    "MVAL0" => %{"enabled" => false}
    }
 end
end
