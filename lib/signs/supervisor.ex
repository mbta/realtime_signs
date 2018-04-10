defmodule Signs.Supervisor do
  @moduledoc """
  Dynamic Supervisor of all the signs. Every hardware sign that we control
  (technically, "zone" of signs that always display the same content), is
  managed by its own GenServer, supervised by this supervisor.

  At app start up, the Signs.Starter task reads the signs.config and uses
  it to call `start_child` on this supervisor.

  Depending on the "type" of sign, this supervisor will start up the
  relevant GenServer. Most signs will be a Signs.Sign, which determines
  its display message from (in priority order) Drupal static text,
  predictions if available, schedules for headways. We also support
  ...?

  (If all the signs are similar "enough", maybe we only need one type of
  GenServer. I'm forgetting all the use cases we discussed for how signs
  could differ. One-liners vs. two? Stops Away vs time? GreenLine Park St
  weird cases?)
  """

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(sign_config) do
    children = make_workers(sign_config)
    supervise(children, strategy: :one_for_one)
  end

  defp make_workers(sign_config) do
    Enum.map(sign_config, fn _ -> worker(Signs.Sign, []) end)
  end
end
