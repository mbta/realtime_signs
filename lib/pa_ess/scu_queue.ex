defmodule PaEss.ScuQueue do
  use GenStage

  def start_link(id) do
    GenStage.start_link(__MODULE__, nil, name: stage_name(id))
  end

  def enqueue_message(id, message) do
    GenStage.call(stage_name(id), {:enqueue_message, message})
  end

  @impl true
  def init(_) do
    {:producer, %{}}
  end

  @impl true
  def handle_call({:enqueue_message, message}, _from, state) do
    {:reply, :ok, [message], state}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def stage_name(id) do
    :"ScuQueue/#{id}"
  end
end
