defmodule Engine.Uids do
  use GenServer

  def start_link(id_initial) do
    {:ok, deploy_counter_text} = File.read("deploy_counter.txt")
    {deploy_count, _} = Integer.parse(deploy_counter_text)

    new_deploy_count =
      deploy_count
      |> increment_deploy_count()
      |> Integer.to_string()

    File.write("deploy_counter.txt", new_deploy_count)

    GenServer.start_link(
      __MODULE__,
      [id_initial: id_initial, deploy_num: deploy_count],
      name: __MODULE__
    )
  end

  @impl true
  def init(opts) do
    {:ok, %{id_counter: opts[:id_initial], deploy_num: opts[:deploy_num]}}
  end

  defp increment_deploy_count(deploy_counter) do
    if deploy_counter + 1 >= 100 do
      0
    else
      deploy_counter + 1
    end
  end

  defp append_deploy_count(id, deploy_count) do
    digits = deploy_count |> Integer.digits()

    case digits do
      [digit | []] ->
        id |> add_a_digit(0) |> add_a_digit(digit)

      [first_digit, second_digit] ->
        id |> add_a_digit(first_digit) |> add_a_digit(second_digit)
    end
  end

  defp add_a_digit(number, digit) do
    number * 10 + digit
  end

  def get_uid(pid) do
    GenServer.call(pid, :get_uid)
  end

  ## Callbacks
  @impl true
  def handle_call(:get_uid, _from, state) do
    next_id = state.id_counter + 1
    uid = next_id |> append_deploy_count(state.deploy_num)
    {:reply, uid, %{state | id_counter: next_id}}
  end
end
