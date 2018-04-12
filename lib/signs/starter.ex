defmodule Signs.Starter do
  def start_link do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    :realtime_signs
    |> :code.priv_dir
    |> Path.join("signs.json")
    |> File.read!
    |> Poison.Parser.parse!
    |> Enum.each(fn sign_config ->
      Signs.Supervisor.start_child(sign_config)
    end)
  end
end
