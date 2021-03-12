defmodule Engine.Health do
  use GenServer
  require Logger

  defstruct [:timer_ref, :network_check_mod, :restart_fn, failed_requests: 0]

  @type t :: %__MODULE__{
          timer_ref: any(),
          failed_requests: integer(),
          network_check_mod: module(),
          restart_fn: (() -> :ok)
        }

  @hackney_pools [:default, :arinc_pool]
  @default_period_ms 60_000
  @failed_request_limit 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    period_ms = Keyword.get(opts, :period_ms, @default_period_ms)
    network_check_mod = Keyword.get(opts, :network_check_mod, Engine.NetworkCheck.Hackney)
    restart_fn = Keyword.get(opts, :restart_fn, Application.get_env(:realtime_signs, :restart_fn))

    {:ok, timer_ref} = :timer.send_interval(period_ms, self(), :health_check)

    {:ok,
     %__MODULE__{
       timer_ref: timer_ref,
       network_check_mod: network_check_mod,
       restart_fn: restart_fn
     }}
  end

  def handle_info(:health_check, state) do
    log_hackney_pools()
    state = check_network(state)

    if state.failed_requests >= @failed_request_limit do
      Logger.error("restarting_application")
      state.restart_fn.()
    end

    {:noreply, state}
  end

  defp log_hackney_pools do
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
  end

  @spec check_network(t()) :: t()
  defp check_network(state) do
    case state.network_check_mod.check() do
      :ok ->
        %{state | failed_requests: 0}

      :error ->
        %{state | failed_requests: state.failed_requests + 1}
    end
  end

  @spec restart_noop() :: :ok
  def restart_noop do
    # A no-op to be used in non-prod environments instead of a real restart.
    # For configuration, releases don't allow function literals, so this is
    # to be used in config.exs like `&Engine.Health.restart_noop/0`.
    :ok
  end
end
