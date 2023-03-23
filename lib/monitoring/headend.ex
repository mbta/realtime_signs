defmodule Monitoring.Headend do
  require Logger

  def update_active_headend_ip(ip) do
    valid? = ip == "172.20.145.20" or ip == "172.20.145.22"
    change? = ip != Application.get_env(:realtime_signs, :sign_head_end_host)
    config_getter = Application.get_env(:realtime_signs, :external_config_getter)

    cond do
      not valid? ->
        Logger.warn("active_headend_ip: invalid ip provided: #{ip}")
        {:bad_request, "bad request"}

      change? ->
        with {:ok, _} = response <- config_getter.put_active_headend_ip(ip) do
          Application.put_env(:realtime_signs, :sign_head_end_host, ip)
          response
        end

      true ->
        Logger.info("active_headend_ip: received: #{ip}")
        {:ok, "unchanged"}
    end
  end
end
