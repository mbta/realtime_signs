defmodule Signs.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    for sign_config <- Signs.Utilities.SignsConfig.children_config() do
      sign_module =
        case sign_config do
          %{"type" => "realtime"} -> Signs.Realtime
          %{"type" => "bus"} -> Signs.Bus
        end

      Supervisor.child_spec({sign_module, sign_config}, id: sign_config["id"])
    end
    |> Supervisor.init(strategy: :one_for_one)
  end
end
