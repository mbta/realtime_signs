defmodule PaEss.Updater do
  require Logger

  @callback set_background_message(
              Signs.Realtime.t() | Signs.Bus.t(),
              Content.Message.value(),
              Content.Message.value()
            ) :: :ok
  def set_background_message(
        %{
          id: id,
          scu_id: scu_id,
          pa_ess_loc: pa_ess_loc,
          text_zone: text_zone,
          default_mode: default_mode
        },
        top,
        bottom
      ) do
    log_config =
      case RealtimeSigns.config_engine().sign_config(id, default_mode) do
        mode when is_atom(mode) -> mode
        mode when is_tuple(mode) -> elem(mode, 0)
        _ -> nil
      end

    visual = zip_pages(top, bottom) |> format_pages()
    tag = create_tag()
    scu_migrated? = RealtimeSigns.config_engine().scu_migrated?(scu_id)

    log_meta = [
      sign_id: id,
      current_config: log_config,
      visual: Jason.encode!(visual),
      tag: inspect(tag),
      legacy: !scu_migrated?
    ]

    if scu_migrated? do
      PaEss.ScuQueue.enqueue_message(
        scu_id,
        {:background, scu_id,
         %{
           visual_zones: [text_zone],
           visual_data: visual,
           expiration: 180,
           tag: tag
         }, log_meta}
      )
    else
      MessageQueue.update_sign({pa_ess_loc, text_zone}, top, bottom, 180, :now, log_meta)
    end
  end

  @callback play_message(
              Signs.Realtime.t() | Signs.Bus.t(),
              [Content.Audio.value()],
              [Content.Audio.tts_value()],
              integer(),
              [keyword()]
            ) ::
              :ok
  def play_message(
        %{
          id: id,
          scu_id: scu_id,
          pa_ess_loc: pa_ess_loc,
          audio_zones: audio_zones
        },
        audios,
        tts_audios,
        priority,
        log_metas
      ) do
    tags = Enum.map(audios, fn _ -> create_tag() end)
    scu_migrated? = RealtimeSigns.config_engine().scu_migrated?(scu_id)

    log_metas =
      Enum.zip([tts_audios, tags, log_metas])
      |> Enum.map(fn {{text, pages}, tag, log_meta} ->
        [
          sign_id: id,
          audio:
            case text do
              {:spanish, text} -> text
              text -> text
            end
            |> inspect(),
          visual: format_pages(pages) |> Jason.encode!(),
          tag: inspect(tag),
          legacy: !scu_migrated?
        ] ++
          log_meta
      end)

    if scu_migrated? do
      Task.Supervisor.start_child(PaEss.TaskSupervisor, fn ->
        files =
          Enum.map(tts_audios, fn {text, _} ->
            Task.async(fn -> fetch_tts(text) end)
          end)
          |> Task.await_many()

        Enum.zip([files, tts_audios, tags, log_metas])
        |> Enum.each(fn {file, {_, pages}, tag, log_meta} ->
          PaEss.ScuQueue.enqueue_message(
            scu_id,
            {:message, scu_id,
             %{
               visual_zones: audio_zones,
               visual_data: format_pages(pages),
               audio_zones: audio_zones,
               audio_data: [Base.encode64(file)],
               expiration: 30,
               priority: priority,
               tag: tag
             }, log_meta}
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

    {voice_id, text} =
      case text do
        {:spanish, text} -> {"Mia", ~s(<prosody rate="90%">#{text}</prosody>)}
        text -> {"Matthew", text}
      end

    text = ~s(<speak><amazon:effect name="drc">#{text}</amazon:effect></speak>)

    http_poster.post(
      "#{watts_url}/tts",
      %{text: text, voice_id: voice_id, output_format: "pcm"} |> Jason.encode!(),
      [
        {"Content-type", "application/json"},
        {"x-api-key", watts_api_key}
      ]
    )
    |> case do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        body
    end
  end

  defp create_tag() do
    :rand.bytes(16) |> Base.encode64(padding: false)
  end
end
