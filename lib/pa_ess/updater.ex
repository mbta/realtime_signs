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
           zones: ["#{pa_ess_loc}-#{text_zone}"],
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
      |> Enum.map(fn {{tts_audio, pages}, tag, log_meta} ->
        case tts_audio do
          {:url, url} ->
            [audio_url: inspect(url)]

          {:spanish, text} ->
            [audio: inspect(text)]

          list when is_list(list) ->
            [audio: Enum.join(list, " ") |> inspect()]

          text ->
            [audio: inspect(text)]
        end ++
          [
            sign_id: id,
            tag: inspect(tag),
            legacy: !scu_migrated?,
            visual: format_pages(pages) |> Jason.encode!()
          ] ++
          log_meta
      end)

    if scu_migrated? do
      Task.Supervisor.start_child(PaEss.TaskSupervisor, fn ->
        async_map = fn list, fun ->
          Task.async_stream(list, fun) |> Enum.map(fn {:ok, value} -> value end)
        end

        file_lists =
          async_map.(tts_audios, fn {tts_audio, _} ->
            List.wrap(tts_audio) |> async_map.(&fetch_audio_file/1)
          end)

        Enum.zip([file_lists, tts_audios, tags, log_metas])
        |> Enum.each(fn {file_list, {_, pages}, tag, log_meta} ->
          PaEss.ScuQueue.enqueue_message(
            scu_id,
            {:message, scu_id,
             %{
               zones: Enum.map(audio_zones, &"#{pa_ess_loc}-#{&1}"),
               visual_data: format_pages(pages),
               audio_data: Enum.map(file_list, &Base.encode64(&1)),
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

  defp fetch_audio_file({:url, url}) do
    http_client = Application.get_env(:realtime_signs, :http_client)

    case http_client.get(url) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status == 200 ->
        body
    end
  end

  defp fetch_audio_file(text) do
    http_poster = Application.get_env(:realtime_signs, :http_poster_mod)
    watts_url = Application.get_env(:realtime_signs, :watts_url)
    watts_api_key = Application.get_env(:realtime_signs, :watts_api_key)

    {voice_id, text} =
      case text do
        {:spanish, text} -> {"Mia", text}
        text -> {"Matthew", text}
      end

    text =
      ~s(<speak><amazon:effect name="drc"><prosody rate="90%">#{xml_escape(text)}</prosody></amazon:effect></speak>)

    http_poster.post(
      "#{watts_url}/tts",
      Jason.encode!(%{text: text, voice_id: voice_id, output_format: "pcm"}),
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

  defp xml_escape(text) do
    String.replace(text, ~w(" ' < > &), fn
      "\"" -> "&quot;"
      "'" -> "&apos;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      "&" -> "&amp;"
    end)
  end
end
