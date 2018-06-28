defmodule MessageQueueTest do
  use ExUnit.Case

  describe "handle_call :queue_update" do
    test "adds message to the queue" do
      q = :queue.new()
      msg = {:msg, [:args]}

      {:reply, {:ok, :sent}, state} = MessageQueue.handle_call({:queue_update, msg}, self(), %{queue: q})

      assert {{:value, ^msg}, _queue} = :queue.out(state.queue)
    end

    test "bumps old message when more than 20" do
      q = 1..20 |> Enum.to_list |> :queue.from_list
      msg = 21

      {:reply, {:ok, :sent}, state} = MessageQueue.handle_call({:queue_update, msg}, self(), %{queue: q})

      assert {{:value, 2}, _queue} = :queue.out(state.queue)
    end
  end

  describe "handle_call :get_message" do
    test "returns item from queue" do
      q = :queue.from_list([:abc])
      assert {:reply, :abc, _new_state} = MessageQueue.handle_call(:get_message, self(), %{queue: q})
    end

    test "returns nil if empty" do
      q = :queue.new()
      assert {:reply, nil, _new_state} = MessageQueue.handle_call(:get_message, self(), %{queue: q})
    end
  end

  describe "works through public interfaces" do
    {:ok, pid} = GenServer.start_link(MessageQueue, [])
    {:ok, :sent} = MessageQueue.update_single_line(pid, 1, 2, 3, 4,5)
    {:ok, :sent} = MessageQueue.update_sign(pid, 1, 2, 3, 4, 5)
    {:ok, :sent} = MessageQueue.send_audio(pid, 1, 2, 3, 4)

    assert MessageQueue.get_message(pid) == {:update_single_line, [1, 2, 3, 4, 5]}
    assert MessageQueue.get_message(pid) == {:update_sign, [1, 2, 3, 4, 5]}
    assert MessageQueue.get_message(pid) == {:send_audio, [1, 2, 3, 4]}
    assert MessageQueue.get_message(pid) == nil
  end
end
