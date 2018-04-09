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

  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(sign_config) do
    sign_mod = case sign_config["type"] do
      "normal" -> Signs.Sign
    end

    DynamicSupervisor.start_child(__MODULE__, {sign_mod, sign_config})
  end

  def init([]) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: []
    )
  end
end
