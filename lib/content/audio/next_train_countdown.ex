defmodule Content.Audio.NextTrainCountdown do
  @moduledoc """
  The next train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :route_id, :verb, :minutes, :track_number]
  defstruct @enforce_keys ++ [:special_sign, platform: nil]

  @type verb :: :arrives | :departs

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          verb: verb(),
          minutes: integer(),
          track_number: Content.Utilities.track_number() | nil,
          platform: Content.platform() | nil,
          special_sign: :jfk_mezzanine | :bowdoin_eastbound | nil
        }

  require Logger
  alias Content.Message

  def from_message(%Message.Predictions{} = message) do
    [
      %__MODULE__{
        destination: message.destination,
        route_id: message.prediction.route_id,
        minutes: if(message.minutes == :approaching, do: 1, else: message.minutes),
        verb: if(message.terminal?, do: :departs, else: :arrives),
        track_number: Content.Utilities.stop_track_number(message.prediction.stop_id),
        platform: Content.Utilities.stop_platform(message.prediction.stop_id),
        special_sign: message.special_sign
      }
    ]
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      min_or_mins = if(audio.minutes == 1, do: :minute, else: :minutes)

      suffix =
        cond do
          audio.track_number == 1 ->
            [:on_track_1]

          audio.track_number == 2 ->
            [:on_track_2]

          !!audio.platform and audio.special_sign == :jfk_mezzanine and audio.minutes >= 10 ->
            [:will_announce_platform_later]

          !!audio.platform and audio.special_sign == :jfk_mezzanine and audio.minutes > 5 ->
            [:will_announce_platform_soon]

          audio.platform ->
            [:on_the, {:destination, audio.platform}, :platform]

          true ->
            []
        end

      early_suffix? = !!audio.platform and audio.minutes == 1

      PaEss.Utilities.audio_message(
        [:the_next] ++
          PaEss.Utilities.train_description_tokens(audio.destination, audio.route_id) ++
          if(early_suffix?, do: suffix, else: []) ++
          [audio.verb, :in, {:number, audio.minutes}, min_or_mins] ++
          if(early_suffix?, do: [], else: suffix)
      )
    end

    def to_tts(%Content.Audio.NextTrainCountdown{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.NextTrainCountdown{}) do
      []
    end

    defp tts_text(%Content.Audio.NextTrainCountdown{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      arrives_or_departs = if audio.verb == :arrives, do: "arrives", else: "departs"
      min_or_mins = if audio.minutes == 1, do: "minute", else: "minutes"

      suffix =
        cond do
          audio.track_number ->
            " on track #{audio.track_number}."

          audio.platform ->
            cond do
              audio.minutes <= 5 ->
                " on the #{if(audio.platform == :ashmont, do: "ashmont", else: "braintree")} platform"

              audio.minutes <= 11 ->
                ". We will announce the platform for boarding soon."

              true ->
                ". We will announce the platform for boarding when the train is closer."
            end

          true ->
            "."
        end

      "The next #{train} #{arrives_or_departs} in #{audio.minutes} #{min_or_mins}#{suffix}"
    end
  end
end
