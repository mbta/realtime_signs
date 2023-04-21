defmodule MessageQueue do
  @moduledoc """
  Simple FIFO queue that stores messages from the signs to the PaEss server.
  Has a buffer of @max_size messages. Requests from clients for messages return
  the oldest available of the @max_size. When the queue is full, drops the oldest
  message to accommodate the new one.
  """

  @behaviour PaEss.Updater

  @type message :: {
          :update_single_line | :update_sign | :send_audio,
          [term()]
        }

  @type t :: %{
          queue: :queue.queue(message()),
          length: integer()
        }

  @max_size 400
  @too_full_drop 30

  use GenServer
  require Logger

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  @spec init(any()) :: {:ok, t()}
  def init(_) do
    {:ok, %{queue: :queue.new(), length: 0}}
  end

  @impl PaEss.Updater
  def update_single_line(pid \\ __MODULE__, text_id, line_no, msg, duration, start) do
    GenServer.call(
      pid,
      {:queue_update, {:update_single_line, [text_id, line_no, msg, duration, start]}}
    )
  end

  @impl PaEss.Updater
  def update_sign(pid \\ __MODULE__, text_id, top_line, bottom_line, duration, start) do
    GenServer.call(
      pid,
      {:queue_update, {:update_sign, [text_id, top_line, bottom_line, duration, start]}}
    )
  end

  @impl PaEss.Updater
  def send_audio(pid \\ __MODULE__, audio_id, audios, priority, timeout) do
    GenServer.call(pid, {:queue_update, {:send_audio, [audio_id, audios, priority, timeout]}})
  end

  @spec get_message(GenServer.server()) :: message() | nil
  def get_message(pid \\ __MODULE__) do
    GenServer.call(pid, :get_message)
  end

  @impl GenServer
  def handle_call({:queue_update, msg}, _from, state) do
    {queue, length} =
      if state.length >= @max_size do
        Logger.warn(["Message queue too full; dropping ", inspect(@too_full_drop)])
        {_, queue} = :queue.split(@too_full_drop, state.queue)
        {queue, state.length - @too_full_drop}
      else
        {state.queue, state.length}
      end

    if length > 0 and rem(length, 30) == 0 do
      Logger.info(["MessageQueue queue_length=", inspect(state.length)])
    end

    queue = :queue.in(msg, queue)

    {:reply, {:ok, :sent}, %{state | queue: queue, length: length + 1}}
  end

  def handle_call(:get_message, _from, state) do
    {result, q} = :queue.out(state.queue)

    message =
      case result do
        {:value, msg} -> msg
        :empty -> nil
      end

    {:reply, message, %{state | queue: q, length: max(0, state.length - 1)}}
  end
end
