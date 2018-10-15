defmodule Signs.Realtime do
  @moduledoc """
  A two-line sign that displays realtime countdown information from one or more sources. See
  Signs.Utilities.SourceConfig for information on the JSON format.
  """

  use GenServer
  require Logger

  alias Signs.Utilities

  @enforce_keys [
    :id,
    :pa_ess_id,
    :source_config,
    :current_content_top,
    :current_content_bottom,
    :prediction_engine,
    :sign_updater,
    :tick_top,
    :tick_bottom,
    :tick_read,
    :expiration_seconds,
    :read_period_seconds
  ]

  defstruct @enforce_keys ++ [announced_arrivals: MapSet.new()]

  @type t :: %__MODULE__{
          id: String.t(),
          pa_ess_id: PaEss.id(),
          source_config: Utilities.SourceConfig.config(),
          current_content_top: {Utilities.SourceConfig.source() | nil, Content.Message.t()},
          current_content_bottom: {Utilities.SourceConfig.source() | nil, Content.Message.t()},
          prediction_engine: module(),
          sign_updater: module(),
          tick_bottom: non_neg_integer(),
          tick_top: non_neg_integer(),
          tick_read: non_neg_integer(),
          expiration_seconds: non_neg_integer(),
          read_period_seconds: non_neg_integer(),
          announced_arrivals: MapSet.t()
        }

  def start_link(%{"type" => "realtime"} = config, opts \\ []) do
    prediction_engine = opts[:prediction_engine] || Engine.Predictions
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    pa_ess_zone = Map.fetch!(config, "pa_ess_zone")

    sign = %__MODULE__{
      id: Map.fetch!(config, "id"),
      pa_ess_id: {Map.fetch!(config, "pa_ess_loc"), pa_ess_zone},
      source_config: config |> Map.fetch!("source_config") |> Utilities.SourceConfig.parse!(),
      current_content_top: {nil, Content.Message.Empty.new()},
      current_content_bottom: {nil, Content.Message.Empty.new()},
      prediction_engine: prediction_engine,
      sign_updater: sign_updater,
      tick_bottom: 130,
      tick_top: 130,
      tick_read: 240 + offset(pa_ess_zone),
      expiration_seconds: 130,
      read_period_seconds: 240
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    schedule_run_loop(self())
    {:ok, sign}
  end

  def handle_info(:run_loop, sign) do
    sign =
      sign
      |> expire_bottom()
      |> expire_top()

    {top, bottom} = Utilities.Predictions.get_messages(sign, Engine.Config.enabled?(sign.id))

    sign =
      sign
      |> Utilities.Updater.update_sign(top, bottom)
      |> Utilities.Reader.read_sign()
      |> decrement_ticks()

    schedule_run_loop(self())
    {:noreply, sign}
  end

  def handle_info(msg, state) do
    Logger.warn("Signs.Realtime unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  def schedule_run_loop(pid) do
    Process.send_after(pid, :run_loop, 1_000)
  end

  defp offset(zone) when zone in ["n", "e"], do: 0
  defp offset(zone) when zone in ["s", "w"], do: 60
  defp offset(zone) when zone in ["m", "c"], do: 120

  def expire_bottom(%{tick_bottom: n} = sign) when n > 0 do
    sign
  end

  def expire_bottom(sign) do
    %{
      sign
      | tick_bottom: sign.expiration_seconds,
        current_content_bottom: {nil, Content.Message.Empty.new()}
    }
  end

  def expire_top(%{tick_top: n} = sign) when n > 0 do
    sign
  end

  def expire_top(sign) do
    %{
      sign
      | tick_top: sign.expiration_seconds,
        current_content_top: {nil, Content.Message.Empty.new()}
    }
  end

  def decrement_ticks(sign) do
    %{
      sign
      | tick_bottom: sign.tick_bottom - 1,
        tick_top: sign.tick_top - 1,
        tick_read: sign.tick_read - 1
    }
  end
end
