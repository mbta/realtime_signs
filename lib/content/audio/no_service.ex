defmodule Content.Audio.NoService do
  @enforce_keys [:destination, :route, :use_shuttle?]
  defstruct @enforce_keys ++ [use_routes?: false]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil,
          use_shuttle?: boolean(),
          use_routes?: boolean()
        }

  defimpl Content.Audio do
    def to_tts(%Content.Audio.NoService{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.NoService{}) do
      []
    end

    defp tts_text(%Content.Audio.NoService{
           route: route,
           destination: destination,
           use_shuttle?: use_shuttle?,
           use_routes?: use_routes?
         }) do
      suffix =
        cond do
          use_shuttle? -> " Use shuttle."
          # Hardcoded for Union Square
          use_routes? -> " Use Routes 87, 91, or 109"
          true -> ""
        end

      if destination do
        destination_text = PaEss.Utilities.destination_to_ad_hoc_string(destination)
        "No #{destination_text} service.#{suffix}"
      else
        line = if(route, do: "#{route} Line", else: "train")
        "There is no #{line} service at this station.#{suffix}"
      end
    end
  end
end
