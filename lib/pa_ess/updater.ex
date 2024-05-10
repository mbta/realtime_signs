defmodule PaEss.Updater do
  @behaviour PaEss.UpdaterAPI

  require Logger

  @impl true
  def set_background_message(
        %{
          id: id,
          scu_id: scu_id,
          pa_ess_loc: pa_ess_loc,
          text_zone: text_zone,
          config_engine: config_engine
        },
        top,
        bottom
      ) do
    if config_engine.scu_migrated?(scu_id) do
      Logger.error("Error sending to new SCU, not implemented")
    else
      MessageQueue.update_sign({pa_ess_loc, text_zone}, top, bottom, 180, :now, id)
    end
  end

  @impl true
  def play_message(
        %{
          id: id,
          scu_id: scu_id,
          pa_ess_loc: pa_ess_loc,
          audio_zones: audio_zones,
          config_engine: config_engine
        },
        audios,
        extra_logs
      ) do
    if config_engine.scu_migrated?(scu_id) do
      Logger.error("Error sending to new SCU, not implemented")
    else
      MessageQueue.send_audio({pa_ess_loc, audio_zones}, audios, 5, 60, id, extra_logs)
    end
  end
end
