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
          default_mode: default_mode,
          config_engine: config_engine
        },
        top,
        bottom
      ) do
    log_config =
      case config_engine.sign_config(id, default_mode) do
        mode when is_atom(mode) -> mode
        mode when is_tuple(mode) -> elem(mode, 0)
        _ -> nil
      end

    log_meta = [sign_id: id, current_config: log_config]

    if config_engine.scu_migrated?(scu_id) do
      pages = zip_pages(top, bottom)

      PaEss.ScuQueue.enqueue_message(
        scu_id,
        {:background, scu_id,
         %{
           visual_zones: [text_zone],
           visual_data: format_pages(pages),
           expiration: 180,
           tag: nil
         }, [visual: inspect(pages)] ++ log_meta}
      )
    else
      MessageQueue.update_sign({pa_ess_loc, text_zone}, top, bottom, 180, :now, log_meta)
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
        tts_audios,
        log_metas
      ) do
    log_metas = Enum.map(log_metas, fn log_meta -> [{:sign_id, id} | log_meta] end)

    if config_engine.scu_migrated?(scu_id) do
      Task.Supervisor.start_child(PaEss.TaskSupervisor, fn ->
        files =
          Enum.map(tts_audios, fn {text, _} ->
            Task.async(fn -> fetch_tts(text) end)
          end)
          |> Task.await_many()

        Enum.zip([files, tts_audios, log_metas])
        |> Enum.each(fn {file, {text, pages}, log_meta} ->
          PaEss.ScuQueue.enqueue_message(
            scu_id,
            {:message, scu_id,
             %{
               visual_zones: audio_zones,
               visual_data: format_pages(pages),
               audio_zones: audio_zones,
               audio_data: [Base.encode64(file)],
               expiration: 30,
               tag: nil
             }, [audio: inspect(text), visual: inspect(pages)] ++ log_meta}
          )
        end)
      end)
    else
      MessageQueue.send_audio({pa_ess_loc, audio_zones}, audios, 5, 60, log_metas)
    end
  end

  defp zip_pages(top, bottom) do
    max_length =
      Enum.map([top, bottom], fn
        str when is_binary(str) -> 1
        list -> length(list)
      end)
      |> Enum.max()

    Enum.map(0..(max_length - 1), fn i ->
      [{top, top_duration}, {bottom, bottom_duration}] =
        Enum.map([top, bottom], fn
          str when is_binary(str) -> {str, 6}
          list -> Enum.at(list, i, List.last(list))
        end)

      if top_duration != bottom_duration do
        Logger.error(
          "duration mismatch when zipping pages: top=#{top_duration} bottom=#{bottom_duration}"
        )
      end

      {top, bottom, top_duration}
    end)
  end

  defp format_pages(nil), do: nil

  defp format_pages(pages) do
    %{
      pages:
        Enum.map(pages, fn {top, bottom, duration} ->
          %{top: top, bottom: bottom, duration: duration}
        end)
    }
  end

  defp fetch_tts(text) do
    http_poster = Application.get_env(:realtime_signs, :http_poster_mod)
    watts_url = Application.get_env(:realtime_signs, :watts_url)
    watts_api_key = Application.get_env(:realtime_signs, :watts_api_key)

    http_poster.post("#{watts_url}/tts", %{text: text, voice_id: "Matthew"} |> Jason.encode!(), [
      {"Content-type", "application/json"},
      {"x-api-key", watts_api_key}
    ])
    |> case do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        body
    end
  end
end
