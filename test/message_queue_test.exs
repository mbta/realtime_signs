defmodule MessageQueueTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "handle_call :queue_update" do
    test "adds message to the queue" do
      state = %{queue: :queue.new(), length: 0}
      msg = {:msg, [:args]}

      {:reply, :ok, state} = MessageQueue.handle_call({:queue_update, msg}, self(), state)

      assert {{:value, ^msg}, _queue} = :queue.out(state.queue)
    end

    test "bumps 15 old messages when more than max size" do
      q = 1..300 |> Enum.to_list() |> :queue.from_list()
      state = %{queue: q, length: 400}
      msg = 201

      {:reply, :ok, state} = MessageQueue.handle_call({:queue_update, msg}, self(), state)

      assert {{:value, 31}, _queue} = :queue.out(state.queue)
      assert state.length == 371
    end

    test "logs if message size is multiple of 30" do
      state = %{queue: :queue.new(), length: 30}

      log =
        capture_log([level: :info], fn ->
          MessageQueue.handle_call({:queue_update, :foo}, self(), state)
        end)

      assert log =~ "queue_length=30"
    end
  end

  describe "handle_call :get_message" do
    test "returns item from queue" do
      state = %{queue: :queue.from_list([:abc]), length: 1}
      assert {:reply, :abc, _new_state} = MessageQueue.handle_call(:get_message, self(), state)
    end

    test "returns nil if empty" do
      state = %{queue: :queue.new(), length: 0}
      assert {:reply, nil, _new_state} = MessageQueue.handle_call(:get_message, self(), state)
    end
  end

  describe "works through public interfaces" do
    {:ok, pid} = GenServer.start_link(MessageQueue, [])
    :ok = MessageQueue.update_sign(pid, 1, 2, 3, 4, 5, [])
    :ok = MessageQueue.send_audio(pid, 1, 2, 3, 4, [[]])

    assert MessageQueue.get_message(pid) == {:update_sign, [1, 2, 3, 4, 5, []]}
    assert MessageQueue.get_message(pid) == {:send_audio, [1, 2, 3, 4, [[]]]}
    assert MessageQueue.get_message(pid) == nil
  end
end
