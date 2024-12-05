defmodule Content.Audio.FollowingTrain do
  @moduledoc """
  The following train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :route_id, :verb, :minutes]
  defstruct @enforce_keys

  @type verb :: :arrives | :departs

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          verb: verb(),
          minutes: integer()
        }

  require Logger

  @spec from_predictions_message(Content.Message.Predictions.t()) :: [
          Content.Audio.FollowingTrain.t()
        ]
  def from_predictions_message(%Content.Message.Predictions{
        minutes: n,
        destination: destination,
        prediction: prediction,
        terminal?: terminal
      })
      when is_integer(n) do
    [
      %__MODULE__{
        destination: destination,
        route_id: prediction.route_id,
        minutes: n,
        verb: arrives_or_departs(terminal)
      }
    ]
  end

  def from_predictions_message(_msg) do
    []
  end

  @spec arrives_or_departs(boolean) :: :arrives | :departs
  defp arrives_or_departs(true), do: :departs
  defp arrives_or_departs(false), do: :arrives

  defimpl Content.Audio do
    alias PaEss.Utilities

    @the_following "667"
    @train_to "507"
    @in_ "504"
    @minutes "505"
    @minute "532"

    def to_params(audio) do
      dest_var = Utilities.destination_var(audio.destination)

      if Utilities.directional_destination?(audio.destination) do
        do_ad_hoc_message(audio)
      else
        green_line_branch = Content.Utilities.route_branch_letter(audio.route_id)

        cond do
          !is_nil(green_line_branch) ->
            green_line_with_branch_params(audio, green_line_branch, dest_var)

          audio.minutes == 1 ->
            {:canned, {"159", [dest_var, verb_var(audio)], :audio}}

          true ->
            {:canned, {"160", [dest_var, verb_var(audio), minutes_var(audio)], :audio}}
        end
      end
    end

    def to_tts(%Content.Audio.FollowingTrain{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.FollowingTrain{}) do
      []
    end

    defp tts_text(%Content.Audio.FollowingTrain{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      arrives_or_departs = if audio.verb == :arrives, do: "arrives", else: "departs"
      min_or_mins = if audio.minutes == 1, do: "minute", else: "minutes"
      "The following #{train} #{arrives_or_departs} in #{audio.minutes} #{min_or_mins}"
    end

    defp do_ad_hoc_message(audio) do
      {:ad_hoc, {tts_text(audio), :audio}}
    end

    @spec green_line_with_branch_params(
            Content.Audio.FollowingTrain.t(),
            Content.Utilities.green_line_branch(),
            String.t()
          ) :: Content.Audio.canned_message()
    defp green_line_with_branch_params(audio, green_line_branch, destination_var) do
      vars = [
        @the_following,
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

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end

    @spec minute_or_minutes(Content.Audio.FollowingTrain.t()) :: String.t()
    defp minute_or_minutes(%Content.Audio.FollowingTrain{minutes: 1}), do: @minute
    defp minute_or_minutes(%Content.Audio.FollowingTrain{}), do: @minutes
  end
end
