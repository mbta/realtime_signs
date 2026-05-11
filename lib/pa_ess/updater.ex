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
              [Signs.Realtime.t() | Signs.Bus.t()],
              [Content.Audio.value()],
              [Content.Audio.tts_value()],
              integer(),
              [keyword()]
            ) ::
              :ok
  def play_message(signs, audios, tts_audios, priority, log_metas) do
    {migrated_signs, legacy_signs} =
      Enum.split_with(signs, &RealtimeSigns.config_engine().scu_migrated?(&1.scu_id))

    tts_audios = Enum.map(tts_audios, fn {audio, visual} -> {List.wrap(audio), visual} end)

    log_data = fn {audio, visual}, sign, legacy? ->
      tag = create_tag()

      {[
         audio:
           Enum.flat_map(audio, fn
             {:silence, _} -> []
             :chime -> []
             {:url, url} -> ["[#{url}]"]
             {:spanish, text} -> [text]
             text -> [text]
           end)
           |> Enum.join(" ")
           |> inspect(),
         sign_id: sign.id,
         tag: inspect(tag),
         legacy: legacy?,
         visual: paginate(visual, sign) |> format_pages() |> Jason.encode!()
       ], tag}
    end

    if migrated_signs != [] do
      tts_items =
        Enum.zip(tts_audios, log_metas)
        |> Enum.chunk_while(
          nil,
          fn
            value, nil ->
              {:cont, value}

            {{audio, nil}, log_meta}, {{acc_audio, nil}, acc_log_meta} ->
              {:cont,
               {{acc_audio ++ [{:silence, 1000}] ++ audio, nil},
                Keyword.merge(acc_log_meta, log_meta)}}

            value, acc ->
              {:cont, acc, value}
          end,
          fn
            nil -> {:cont, nil}
            acc -> {:cont, acc, nil}
          end
        )
        |> Enum.map(fn {{audio, visual}, log_meta} ->
          {{[:chime] ++ audio ++ [{:silence, 1000}], visual}, log_meta}
        end)

      Enum.each(migrated_signs, fn sign ->
        Enum.each(tts_items, fn {{audio, visual} = tts_audio, log_meta} ->
          {logs, tag} = log_data.(tts_audio, sign, false)

          PaEss.ScuQueue.enqueue_message(
            sign.scu_id,
            {:message, sign.scu_id,
             %{
               zones: Enum.map(sign.audio_zones, &"#{sign.pa_ess_loc}-#{&1}"),
               visual_data: paginate(visual, sign) |> format_pages(),
               audio_data: Enum.map(audio, &format_audio/1),
               expiration: 30,
               priority: priority,
               tag: tag
             }, Keyword.merge(logs, log_meta)}
          )
        end)
      end)
    end

    Enum.each(legacy_signs, fn sign ->
      log_list =
        Enum.zip(tts_audios, log_metas)
        |> Enum.map(fn {tts_audio, log_meta} ->
          {logs, _tag} = log_data.(tts_audio, sign, true)
          Keyword.merge(logs, log_meta)
        end)

      MessageQueue.send_audio({sign.pa_ess_loc, sign.audio_zones}, audios, 5, 60, log_list)
    end)
  end

  defp paginate(nil, _sign), do: nil

  defp paginate(text, sign) do
    max_text_length = PaEss.Utilities.max_text_length(sign.scu_id)
    PaEss.Utilities.paginate_text(text, max_text_length)
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

  defp format_audio(:chime), do: %{type: "chime"}
  defp format_audio({:silence, duration}), do: %{type: "silence", duration: duration}
  defp format_audio({:url, url}), do: %{type: "url", url: url}
  defp format_audio({:spanish, text}), do: %{type: "tts", text: ssml(text), voice_id: "Mia"}
  defp format_audio(text), do: %{type: "tts", text: ssml(text), voice_id: "Matthew"}

  defp ssml(text) do
    content = xml_escape(text)

    ~s(<speak><amazon:effect name="drc"><prosody rate="90%">#{content}</prosody></amazon:effect></speak>)
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
