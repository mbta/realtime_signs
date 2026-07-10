defmodule Engine.Health do
  use GenServer

  require Logger

  @hackney_pools [:default, :arinc_pool]
  @default_period_ms 60_000
  @process_health_interval_ms 300_000
  @process_metrics ~w(memory binary_memory heap_size total_heap_size message_queue_len reductions)a

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    period_ms = Keyword.get(opts, :period_ms, @default_period_ms)

    {:ok, _timer_ref} = :timer.send_interval(period_ms, self(), :health_check)
    {:ok, _timer_ref} = :timer.send_interval(@process_health_interval_ms, self(), :process_health)

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:health_check, state) do
    log_hackney_pools()
    {:noreply, state}
  end

  def handle_info(:process_health, state) do
    diagnostic_processes()
    |> Stream.map(&process_metrics/1)
    |> Enum.each(fn {name, supervisor, metrics} ->
      Logger.info([
        "realtime_signs_process_health name=#{inspect(name)} supervisor=#{inspect(supervisor)} ",
        metrics
      ])
    end)

    {:noreply, state}
  end

  defp log_hackney_pools do
    Enum.each(
      @hackney_pools,
      fn pool ->
        stats = :hackney_pool.get_stats(pool)

        Logger.info(
          "event=pool_info name=#{pool} pool_max=#{stats[:max]} in_use_count=#{stats[:in_use_count]} free_count=#{stats[:free_count]} queue_count=#{stats[:queue_count]}"
        )
      end
    )
  end

  @type process_info() :: {pid(), name :: term(), supervisor :: term()}

  @spec diagnostic_processes() :: Enumerable.t()
  defp diagnostic_processes do
    [
      Stream.flat_map(Supervisor.which_children(RealtimeSigns), &descendants(&1, RealtimeSigns)),
      top_processes_by(:memory, limit: 20),
      top_processes_by(:binary_memory, limit: 20)
    ]
    |> Stream.concat()
    |> Stream.uniq_by(&elem(&1, 0))
  end

  @spec top_processes_by(atom(), limit: non_neg_integer()) :: Enumerable.t()
  defp top_processes_by(attribute, limit: limit) do
    Stream.map(:recon.proc_count(attribute, limit), &recon_entry/1)
  end

  @spec descendants(
          {name :: term(), child :: Supervisor.child() | :restarting,
           type :: :worker | :supervisor, modules :: [module()] | :dynamic},
          supervisor :: term()
        ) :: nil | [] | [process_info()]
  defp descendants({_name, status, _type, _modules}, _supervisor) when is_atom(status), do: []

  defp descendants({name, pid, :supervisor, _modules}, _supervisor) do
    if Process.alive?(pid) do
      pid |> Supervisor.which_children() |> Stream.flat_map(&descendants(&1, name))
    end
  end

  defp descendants({name, pid, _, _}, supervisor), do: [{pid, name, supervisor}]

  @spec recon_entry(:recon.proc_attrs()) :: process_info()
  defp recon_entry({pid, _count, [name | _]}) when is_atom(name), do: {pid, name, nil}
  defp recon_entry({pid, _count, _info}), do: {pid, nil, nil}

  @spec process_metrics({pid(), term() | nil, term() | nil}) :: {term(), term(), iodata()}
  defp process_metrics({pid, name, supervisor}) do
    metrics =
      pid
      |> safe_recon_info(@process_metrics)
      |> Stream.map(fn {metric, value} -> "#{metric}=#{value}" end)
      |> Enum.intersperse(" ")

    {name, supervisor, metrics}
  end

  # work around https://github.com/ferd/recon/issues/95
  @spec safe_recon_info(pid(), [atom()]) ::
          [] | [{:recon.info_type(), [{:recon.info_key(), term()}]}]
  defp safe_recon_info(pid, metrics) do
    :recon.info(pid, metrics)
  rescue
    FunctionClauseError -> []
  end
end
