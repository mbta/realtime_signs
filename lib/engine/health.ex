defmodule Engine.Health do
  use GenServer
  require Logger

  @hackney_pools [:default, :arinc_pool]
  @default_period_ms 60_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    period_ms = Keyword.get(opts, :period_ms, @default_period_ms)
    GenServer.start_link(__MODULE__, period_ms, name: name)
  end

  @spec health_check(GenServer.server()) :: {:ok, []}
  def health_check(pid) do
    GenServer.call(pid, :health_check)
  end

  def init(period_ms) do
    {:ok, timer_ref} = :timer.apply_interval(period_ms, __MODULE__, :health_check, [self()])
    {:ok, timer_ref}
  end

  def handle_call(:health_check, _from, timer_ref) do
    Enum.each(
      @hackney_pools,
      fn pool ->
        stats = :hackney_pool.get_stats(pool)

        Logger.info(
          "event=pool_info name=#{pool} pool_max=#{stats[:max]} in_use_count=#{
            stats[:in_use_count]
          } free_count=#{stats[:free_count]} queue_count=#{stats[:queue_count]}"
        )
      end
    )

    {:reply, [], timer_ref}
  end
end
