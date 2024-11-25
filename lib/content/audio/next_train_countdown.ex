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

    @the_next "501"
    @train_to "507"
    @on_track_1 "541"
    @on_track_2 "542"
    @in_ "504"
    @minutes "505"
    @minute "532"
    @platform_soon "849"
    @platform_when_closer "857"

    def to_params(audio) do
      dest_var = Utilities.destination_var(audio.destination)
      green_line_branch = Content.Utilities.route_branch_letter(audio.route_id)

      cond do
        Utilities.directional_destination?(audio.destination) ->
          do_ad_hoc_message(audio)

        !is_nil(audio.track_number) ->
          terminal_track_params(audio, dest_var)

        !is_nil(green_line_branch) ->
          green_line_with_branch_params(audio, green_line_branch, dest_var)

        is_nil(audio.platform) and audio.minutes == 1 ->
          {:canned, {"141", [dest_var, verb_var(audio)], :audio}}

        is_nil(audio.platform) ->
          {:canned, {"90", [dest_var, verb_var(audio), minutes_var(audio)], :audio}}

        audio.minutes == 1 ->
          {:canned, {"142", [dest_var, platform_var(audio), verb_var(audio)], :audio}}

        audio.destination == :alewife and audio.special_sign == :jfk_mezzanine and
            audio.minutes > 5 ->
          platform_tbd_params(
            audio,
            dest_var,
            if(audio.minutes < 10, do: @platform_soon, else: @platform_when_closer)
          )

        true ->
          {:canned,
           {"98", [dest_var, verb_var(audio), minutes_var(audio), platform_var(audio)], :audio}}
      end
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

    defp do_ad_hoc_message(audio) do
      {:ad_hoc, {tts_text(audio), :audio}}
    end

    @spec green_line_with_branch_params(
            Content.Audio.NextTrainCountdown.t(),
            Content.Utilities.green_line_branch(),
            String.t()
          ) :: Content.Audio.canned_message()
    defp green_line_with_branch_params(audio, green_line_branch, destination_var) do
      vars = [
        @the_next,
        PaEss.Utilities.green_line_branch_var(green_line_branch),
        @train_to,
        destination_var,
        verb_var(audio),
        @in_,
        minutes_var(audio),
        minute_or_minutes(audio)
      ]

      Utilities.take_message(vars, :audio)
    end

    @spec terminal_track_params(Content.Audio.NextTrainCountdown.t(), String.t()) ::
            Content.Audio.canned_message()
    defp terminal_track_params(audio, destination_var) do
      vars = [
        @the_next,
        @train_to,
        destination_var,
        verb_var(audio),
        @in_,
        minutes_var(audio),
        minute_or_minutes(audio),
        track(audio.track_number)
      ]

      Utilities.take_message(vars, :audio)
    end

    defp platform_tbd_params(audio, destination_var, platform_message_var) do
      vars = [
        @the_next,
        @train_to,
        destination_var,
        verb_var(audio),
        @in_,
        minutes_var(audio),
        minute_or_minutes(audio),
        platform_message_var
      ]

      Utilities.take_message(vars, :audio)
    end

    defp platform_var(%{platform: :ashmont}), do: "4016"
    defp platform_var(%{platform: :braintree}), do: "4021"

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end

    @spec minute_or_minutes(Content.Audio.NextTrainCountdown.t()) :: String.t()
    defp minute_or_minutes(%Content.Audio.NextTrainCountdown{minutes: 1}), do: @minute
    defp minute_or_minutes(%Content.Audio.NextTrainCountdown{}), do: @minutes

    @spec track(Content.Utilities.track_number()) :: String.t()
    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2
  end
end
