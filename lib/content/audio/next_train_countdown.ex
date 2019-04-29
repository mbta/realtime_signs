defmodule Content.Audio.NextTrainCountdown do
  @moduledoc """
  The next train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :verb, :minutes, :track_number]
  defstruct @enforce_keys ++ [platform: nil]

  @type verb :: :arrives | :departs
  @type platform :: :ashmont | :braintree | nil

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          verb: verb(),
          minutes: integer(),
          track_number: Content.Utilities.track_number() | nil,
          platform: :ashmont | :braintree | nil
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

    def to_params(%{platform: nil, minutes: 1, track_number: track_number} = audio) do
      case track_number do
        nil ->
          {"141", [Utilities.destination_var(audio.destination), verb_var(audio)], :audio}

        _ ->
          terminal_track_params(audio, track_number)
      end
    end

    def to_params(%{platform: nil, track_number: track_number} = audio) do
      case track_number do
        nil ->
          {"90",
           [Utilities.destination_var(audio.destination), verb_var(audio), minutes_var(audio)],
           :audio}

        _ ->
          terminal_track_params(audio, track_number)
      end
    end

    def to_params(%{minutes: 1} = audio) do
      {"142",
       [
         Utilities.destination_var(audio.destination),
         platform_var(audio),
         verb_var(audio)
       ], :audio}
    end

    def to_params(audio) do
      {"99",
       [
         Utilities.destination_var(audio.destination),
         platform_var(audio),
         verb_var(audio),
         minutes_var(audio)
       ], :audio}
    end

    @spec terminal_track_params(
            Content.Audio.NextTrainCountdown.t(),
            Content.Utilities.track_number()
          ) :: {String.t(), [String.t()], :audio}
    defp terminal_track_params(audio, track_number) do
      vars = [
        @the_next,
        @space,
        @train_to,
        @space,
        Utilities.destination_var(audio.destination),
        @space,
        verb_var(audio),
        @space,
        @in_,
        @space,
        minutes_var(audio),
        @space,
        @minutes,
        @space,
        track(track_number)
      ]

      {Utilities.take_message_id(vars), vars, :audio}
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
