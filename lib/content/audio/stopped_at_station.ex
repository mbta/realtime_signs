defmodule Content.Audio.StoppedAtStation do
  @moduledoc """
  The next train to [destination] is waiting at [station]
  """

  require Logger

  @enforce_keys [:destination, :stopped_at]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: atom(),
          stopped_at: atom()
        }

  @spec from_message(Content.Message.StoppedAtStation.t()) :: Content.Audio.StoppedAtStation.t()
  def from_message(%Content.Message.StoppedAtStation{} = msg) do
    %__MODULE__{destination: msg.destination, stopped_at: msg.stopped_at}
  end

  defimpl Content.Audio do
    @destination_var %{
      forest_hills: "824",
      oak_grove: "825"
    }

    @stopped_at_var %{
      assembly: "826",
      back_bay: "827",
      chinatown: "828",
      community_college: "829",
      downtown_crossing: "830",
      forest_hills: "831",
      green_street: "832",
      haymarket: "833",
      jackson_square: "834",
      malden_center: "835",
      massachusetts_avenue: "836",
      north_station: "837",
      oak_grove: "838",
      roxbury_crossing: "839",
      ruggles: "840",
      state: "841",
      stony_brook: "842",
      sullivan_square: "843",
      tufts_medical_center: "844",
      wellington: "845"
    }
    def to_params(%Content.Audio.StoppedAtStation{} = audio) do
      with {:ok, dest_var} <- Map.fetch(@destination_var, audio.destination),
           {:ok, stopped_var} <- Map.fetch(@stopped_at_var, audio.stopped_at) do
        PaEss.Utilities.take_message([dest_var, stopped_var], :audio)
      end
    end
  end
end
