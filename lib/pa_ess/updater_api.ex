defmodule PaEss.UpdaterAPI do
  @callback set_background_message(
              Signs.Realtime.t() | Signs.Bus.t(),
              Content.Message.value(),
              Content.Message.value()
            ) :: :ok

  @callback play_message(Signs.Realtime.t() | Signs.Bus.t(), [Content.Audio.value()], [keyword()]) ::
              :ok
end
