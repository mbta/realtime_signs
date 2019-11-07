defmodule Content.Audio.NextTrainCountdown do
  @moduledoc """
  The next train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :verb, :minutes, :track_number]
  defstruct @enforce_keys ++ [platform: nil]

  @type verb :: :arrives | :departs

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          verb: verb(),
          minutes: integer(),
          track_number: Content.Utilities.track_number() | nil,
          platform: Content.platform() | nil
        }

  require Logger

  defimpl Content.Audio do
    alias PaEss.Utilities

    @the_next "501"
    @train_to "507"
    @on_track_1 "541"
    @on_track_2 "542"
    @in_ "504"
    @minutes "505"
    @space "21000"

    def to_params(%{destination: :southbound, verb: verb, minutes: minutes} = audio) do
      min_or_mins = if minutes == 1, do: "minute", else: "minutes"
      text = "The next southbound train #{verb} in #{minutes} #{min_or_mins}"

      text =
        if audio.track_number do
          text <> " from track #{audio.track_number}"
        else
          text
        end

      {:ad_hoc, {text, :audio}}
    end

    def to_params(audio) do
      case Utilities.destination_var(audio.destination) do
        {:ok, dest_var} ->
          cond do
            !is_nil(audio.track_number) ->
              terminal_track_params(audio, dest_var)

            is_nil(audio.platform) and audio.minutes == 1 ->
              {:canned, {"141", [dest_var, verb_var(audio)], :audio}}

            is_nil(audio.platform) ->
              {:canned, {"90", [dest_var, verb_var(audio), minutes_var(audio)], :audio}}

            audio.minutes == 1 ->
              {:canned, {"142", [dest_var, platform_var(audio), verb_var(audio)], :audio}}

            true ->
              {:canned,
               {"99", [dest_var, platform_var(audio), verb_var(audio), minutes_var(audio)],
                :audio}}
          end

        {:error, :unknown} ->
          Logger.error("NextTrainCountdown unknown destination: #{inspect(audio.destination)}")
          nil
      end
    end

    @spec terminal_track_params(Content.Audio.NextTrainCountdown.t(), String.t()) ::
            Content.Audio.canned_message()
    defp terminal_track_params(audio, destination_var) do
      vars = [
        @the_next,
        @space,
        @train_to,
        @space,
        destination_var,
        @space,
        verb_var(audio),
        @space,
        @in_,
        @space,
        minutes_var(audio),
        @space,
        @minutes,
        @space,
        track(audio.track_number)
      ]

      {:canned, {Utilities.take_message_id(vars), vars, :audio}}
    end

    defp platform_var(%{platform: :ashmont}), do: "4016"
    defp platform_var(%{platform: :braintree}), do: "4021"

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end

    @spec track(Content.Utilities.track_number()) :: String.t()
    defp track(1), do: @on_track_1
    defp track(2), do: @on_track_2
  end
end
