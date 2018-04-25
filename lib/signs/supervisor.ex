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

  def start_link do
    Supervisor.start_link(children(), name: __MODULE__, strategy: :one_for_one)
  end

  defp children() do
    for sign_config <- children_config() do
      sign_module = sign_module(sign_config)
      %{
        id: :"sign_#{sign_config["id"]}",
        start: {sign_module, :start_link, [sign_config]}
      }
    end
  end

  defp sign_module(%{"type" => "countdown"}), do: Signs.Countdown
  defp sign_module(%{"type" => "ashmont"}), do: Signs.Ashmont
  defp sign_module(%{"type" => "headway"}), do: Signs.Headway

  defp children_config() do
    :realtime_signs
    |> :code.priv_dir
    |> Path.join("signs.json")
    |> File.read!
    |> Poison.Parser.parse!
  end
end
