defmodule Signs.Headway do
  use GenServer
  require Logger
  @enforce_keys [
    :id,
    :pa_ess_id,
    :gtfs_stop_id,
    :route_id,
    :headsign,
    :headyway_engine,
    :sign_updater
  ]

  defstruct @enforce_keys ++ [
    :current_content_bottom,
    :current_content_top,
    :timer,
  ]

  @type t :: %{
    id: String.t(),
    pa_ess_id: PaEss.id(),
    gtfs_stop_id: String.t(),
    route_id: String.t(),
    headsign: String.t(),
    headyway_engine: module(),
    sign_updater: module(),
    current_content_bottom: Content.Message.t() | nil,
    current_content_top: Content.Message.t() | nil,
    timer: reference() | nil,
  }

  def start_link(%{"type" => "headway"} = config, opts \\ []) do
    sign_updater = opts[:sign_updater] || Application.get_env(:realtime_signs, :sign_updater_mod)
    headyway_engine = opts[:headyway_engine] || Engine.Schedules

    sign = %__MODULE__{
      id: config["id"],
      pa_ess_id: {config["pa_ess_loc"], config["pa_ess_zone"]},
      gtfs_stop_id: config["gtfs_stop_id"],
      route_id: config["route_id"],
      headsign: config["headsign"],
      current_content_top: Content.Message.Empty.new(),
      current_content_bottom: Content.Message.Empty.new(),
      timer: nil,
      sign_updater: sign_updater,
      headyway_engine: headyway_engine,
    }

    GenServer.start_link(__MODULE__, sign)
  end

  def init(sign) do
    Engine.Headways.register(sign.gtfs_stop_id)
    {:ok, sign}
  end
end
