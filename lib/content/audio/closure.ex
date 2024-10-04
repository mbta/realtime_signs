defmodule Content.Audio.Closure do
  @moduledoc """
  Audio message for a station where service is replaced by shuttle buses or suspended entirely.
  """

  require Logger

  @enforce_keys [:alert]
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{
          alert: :shuttles_closed_station | :suspension_closed_station,
          route: String.t() | nil
        }

  @spec from_messages(Content.Message.t(), Content.Message.t()) :: [t()]
  def from_messages(
        %Content.Message.Alert.NoService{route: route},
        %Content.Message.Alert.UseShuttleBus{}
      ) do
    [%Content.Audio.Closure{alert: :shuttles_closed_station, route: route}]
  end

  def from_messages(%Content.Message.Alert.NoService{route: route}, %Content.Message.Empty{}) do
    [%Content.Audio.Closure{alert: :suspension_closed_station, route: route}]
  end

  def from_messages(%Content.Message.Alert.NoService{}, %Content.Message.Alert.UseRoutes{}) do
    [%Content.Audio.Closure{alert: :use_routes_alert}]
  end

  def from_messages(top, bottom) do
    Logger.error("message_to_audio_error Audio.Closure #{inspect(top)} #{inspect(bottom)}")
    []
  end

  defimpl Content.Audio do
    @there_is_no "861"
    @service_at_this_station "863"

    def to_params(%Content.Audio.Closure{alert: :shuttles_closed_station, route: route}) do
      {:canned, {"199", [PaEss.Utilities.line_to_var(route)], :audio}}
    end

    def to_params(%Content.Audio.Closure{alert: :suspension_closed_station, route: route}) do
      line_var = PaEss.Utilities.line_to_var(route)
      PaEss.Utilities.take_message([@there_is_no, line_var, @service_at_this_station], :audio)
    end

    # Hardcoded for Union Square
    def to_params(%Content.Audio.Closure{alert: :use_routes_alert, route: nil} = audio) do
      {:ad_hoc, {tts_text(audio), :audio}}
    end

    def to_tts(%Content.Audio.Closure{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.Closure{}) do
      []
    end

    defp tts_text(%Content.Audio.Closure{route: route} = audio) do
      if audio.alert == :use_routes_alert do
        # Hardcoded for Union Square
        "No Train Service. Use routes 86, 87, or 91"
      else
        shuttle = if(audio.alert == :shuttles_closed_station, do: " Use shuttle.", else: "")
        line = if(route, do: "#{route} Line", else: "train")
        "There is no #{line} service at this station.#{shuttle}"
      end
    end
  end
end
