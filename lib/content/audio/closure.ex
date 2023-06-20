defmodule Content.Audio.Closure do
  @moduledoc """
  Audio message for a station where service is replaced by shuttle buses or suspended entirely.
  """

  require Logger

  @enforce_keys [:alert, :routes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          alert: :shuttles_closed_station | :suspension_closed_station,
          routes: [String.t()]
        }

  @spec from_messages(Content.Message.t(), Content.Message.t()) :: [t()]
  def from_messages(
        %Content.Message.Alert.NoService{routes: routes},
        %Content.Message.Alert.UseShuttleBus{}
      ) do
    [%Content.Audio.Closure{alert: :shuttles_closed_station, routes: routes}]
  end

  def from_messages(%Content.Message.Alert.NoService{routes: routes}, %Content.Message.Empty{}) do
    [%Content.Audio.Closure{alert: :suspension_closed_station, routes: routes}]
  end

  def from_messages(top, bottom) do
    Logger.error("message_to_audio_error Audio.Closure #{inspect(top)} #{inspect(bottom)}")
    []
  end

  defimpl Content.Audio do
    def to_params(%Content.Audio.Closure{alert: :shuttles_closed_station, routes: routes}) do
      line_var =
        PaEss.Utilities.get_line_from_routes_list(routes) |> PaEss.Utilities.line_to_var()

      {:canned, {"199", [line_var], :audio}}
    end

    def to_params(%Content.Audio.Closure{alert: :suspension_closed_station, routes: routes}) do
      line_var =
        PaEss.Utilities.get_line_from_routes_list(routes) |> PaEss.Utilities.line_to_var()

      {:canned, {"90130", [], :audio}}
    end
  end
end
