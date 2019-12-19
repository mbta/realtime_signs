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

  @spec from_predictions_message({
          Signs.Utilities.SourceConfig.source(),
          Content.Message.Predictions.t()
        }) :: Content.Audio.FollowingTrain.t() | nil
  def from_predictions_message({
        %{
          terminal?: terminal
        },
        %Content.Message.Predictions{minutes: n, headsign: headsign, route_id: route_id}
      })
      when is_integer(n) do
    case PaEss.Utilities.headsign_to_destination(headsign) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
          route_id: route_id,
          minutes: n,
          verb: arrives_or_departs(terminal)
        }

      {:error, :unknown} ->
        Logger.warn(
          "Content.Audio.FollowingTrain.from_predictions_message: unknown headsign: #{headsign}"
        )

        nil
    end
  end

  def from_predictions_message({_src, _msg}) do
    nil
  end

  @spec arrives_or_departs(boolean) :: :arrives | :departs
  defp arrives_or_departs(true), do: :departs
  defp arrives_or_departs(false), do: :arrives

  defimpl Content.Audio do
    alias PaEss.Utilities

    @priority 3

    @the_following "667"
    @train_to "507"
    @in_ "504"
    @minutes "505"
    @minute "532"

    def to_params(%{destination: :southbound, verb: verb, minutes: minutes}) do
      min_or_mins = if minutes == 1, do: "minute", else: "minutes"
      text = "The following southbound train #{verb} in #{minutes} #{min_or_mins}"
      {:ad_hoc, {text, :audio, @priority}}
    end

    def to_params(audio) do
      case Utilities.destination_var(audio.destination) do
        {:ok, dest_var} ->
          green_line_branch =
            Content.Utilities.route_and_destination_branch_letter(
              audio.route_id,
              audio.destination
            )

          cond do
            !is_nil(green_line_branch) ->
              green_line_with_branch_params(audio, green_line_branch, dest_var)

            audio.minutes == 1 ->
              {:canned, {"159", [dest_var, verb_var(audio)], :audio, @priority}}

            true ->
              {:canned,
               {"160", [dest_var, verb_var(audio), minutes_var(audio)], :audio, @priority}}
          end

        {:error, :unknown} ->
          Logger.error(
            "FollowingTrain.to_params unknown destination: #{inspect(audio.destination)}"
          )

          nil
      end
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

      Utilities.take_message(vars, :audio, @priority)
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
