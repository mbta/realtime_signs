defmodule Content.Audio.FollowingTrain do
  @moduledoc """
  The following train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :verb, :minutes]
  defstruct @enforce_keys

  @type verb :: :arrives | :departs

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
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
        %Content.Message.Predictions{minutes: n, headsign: headsign}
      })
      when is_integer(n) do
    case PaEss.Utilities.headsign_to_destination(headsign) do
      {:ok, destination} ->
        %__MODULE__{
          destination: destination,
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

    def to_params(%{destination: :southbound, verb: verb, minutes: minutes}) do
      min_or_mins = if minutes == 1, do: "minute", else: "minutes"
      text = "The following southbound train #{verb} in #{minutes} #{min_or_mins}"
      {:ad_hoc, {text, :audio}}
    end

    def to_params(audio) do
      case Utilities.destination_var(audio.destination) do
        {:ok, dest_var} ->
          if audio.minutes == 1 do
            {:canned, {"159", [dest_var, verb_var(audio)], :audio}}
          else
            {:canned, {"160", [dest_var, verb_var(audio), minutes_var(audio)], :audio}}
          end

        {:error, :unknown} ->
          Logger.error(
            "FollowingTrain.to_params unknown destination: #{inspect(audio.destination)}"
          )

          nil
      end
    end

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end
  end
end
