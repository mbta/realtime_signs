defmodule Engine.NetworkCheck.Finch do
  require Logger

  @behaviour Engine.NetworkCheck

  @impl Engine.NetworkCheck
  def check(url \\ "https://www.google.com/") do
    response =
      Finch.build(
        :get,
        url
      )
      |> Finch.request(HttpClient)

    case response do
      {:ok, %Finch.Response{status: status}} when status >= 200 and status <= 302 ->
        Logger.info("#{__MODULE__} check_network result=success")
        :ok

      _ ->
        Logger.warn("#{__MODULE__} check_network result=failure resp=#{inspect(response)}")
        :error
    end
  end
end
