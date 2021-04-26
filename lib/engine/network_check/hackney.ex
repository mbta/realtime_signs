defmodule Engine.NetworkCheck.Hackney do
  require Logger

  @behaviour Engine.NetworkCheck

  @impl Engine.NetworkCheck
  def check(url \\ "https://www.google.com/") do
    response =
      :hackney.request(:head, url, [], "", [
        :skip_body,
        connect_timeout: 1000,
        recv_timeout: 1000
      ])

    case response do
      {:ok, status, _} when status >= 200 and status < 300 ->
        Logger.info("#{__MODULE__} check_network result=success")
        :ok

      _ ->
        Logger.warn("#{__MODULE__} check_network result=failure resp=#{inspect(response)}")
        :error
    end
  end
end
