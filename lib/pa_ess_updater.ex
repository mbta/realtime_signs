defmodule PaEssUpdater do
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def update_sign(pa_ess_id, content) do
    text = Content.Predictions.to_text(content) # this could be a @behaviour to handle different kinds of messages
    Logger.info("Updated sign #{inspect(pa_ess_id)} with: #{text}")
  end

  def init([]) do
    {:ok, []}
  end
end
