defmodule Monitoring.Headend do
  require Logger

  def update_active_headend_ip(ip) do
    valid? = ip == "172.20.145.20" or ip == "172.20.145.22"

    if valid? do
      ExternalConfig.S3.put_active_headend_ip(ip)
    else
      Logger.warn("active_headend_ip: Invalid IP provided: #{ip}")
      {:bad_request, "Bad request"}
    end
  end
end
