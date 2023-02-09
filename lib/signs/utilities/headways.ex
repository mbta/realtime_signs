defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig
  require Logger

  @spec get_messages(Signs.Realtime.t(), DateTime.t()) :: Signs.Utilities.Messages.sign_messages()
  def get_messages(sign, current_time) do
    config = single_source_config(sign) || config_by_headway_id(sign)

    # If the sign is single source or there is a source marked as source_for_headway, prefer that one.
    # Otherwise, default to using the first source available.
    headways =
      if config do
        sign.config_engine.headway_config(config.headway_group, current_time)
      else
        SourceConfig.headway_group_from_source_config(sign.source_config)
        |> sign.config_engine.headway_config(current_time)
      end

    stop_ids = get_stop_ids(sign, config)

    if display_headways?(sign, stop_ids, current_time, headways) do
      destination = get_destination(config)
      get_headway_messages(config, destination, headways)
    else
      get_empty_messages(config)
    end
  end

  @spec get_paging_message(
          Signs.Realtime.t(),
          list(SourceConfig.source()),
          DateTime.t()
        ) :: Content.Message.Headways.Paging.t()
  def get_paging_message(sign, config, current_time) do
    case sign.config_engine.headway_config(
           SourceConfig.headway_group_from_source_list(config),
           current_time
         ) do
      nil ->
        %Content.Message.Empty{}

      headways ->
        config |> source_list_destination() |> get_paging_headway_message(headways)
    end
  end

  @spec display_headways?(
          Signs.Realtime.t(),
          [String.t()],
          DateTime.t(),
          Engine.Config.Headway.t() | nil
        ) :: boolean()
  defp display_headways?(_sign, _stop_ids, _current_time, nil), do: false

  defp display_headways?(sign, stop_ids, current_time, headways) do
    sign.headway_engine.display_headways?(stop_ids, current_time, headways.range_high)
  end

  @spec get_stop_ids(Signs.Realtime.t(), SourceConfig.source() | nil) :: [String.t()]
  defp get_stop_ids(sign, nil), do: Signs.Utilities.SourceConfig.sign_stop_ids(sign.source_config)
  defp get_stop_ids(sign, config), do: [sign.headway_stop_id || config.stop_id]

  @spec source_list_destination(list(SourceConfig.source())) :: PaEss.destination() | nil
  def source_list_destination(config) do
    config
    |> Enum.map(& &1.headway_destination)
    |> Enum.uniq()
    |> case do
      [destination] -> destination
      _ -> nil
    end
  end

  @spec get_destination(SourceConfig.source() | nil) ::
          PaEss.destination() | nil
  defp get_destination(nil), do: nil

  defp get_destination(config), do: config.headway_destination

  @spec get_headway_messages(
          SourceConfig.source() | nil,
          PaEss.destination() | nil,
          Engine.Config.Headway.t()
        ) :: Signs.Utilities.Messages.sign_messages()
  defp get_headway_messages(config, destination, headways) do
    {{config,
      %Content.Message.Headways.Top{
        destination: destination,
        vehicle_type: :train
      }},
     {config,
      %Content.Message.Headways.Bottom{
        range: {headways.range_low, headways.range_high},
        prev_departure_mins: nil
      }}}
  end

  @spec get_paging_headway_message(
          PaEss.destination() | nil,
          Engine.Config.Headway.t()
        ) :: Content.Message.Headways.Paging.t()
  defp get_paging_headway_message(destination, headways) do
    %Content.Message.Headways.Paging{
      destination: destination,
      range: {headways.range_low, headways.range_high}
    }
  end

  @spec get_empty_messages(SourceConfig.source() | nil) ::
          Signs.Utilities.Messages.sign_messages()
  defp get_empty_messages(config) do
    {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}
  end

  @spec config_by_headway_id(Signs.Realtime.t()) :: SourceConfig.source() | nil
  defp config_by_headway_id(sign) do
    sign.source_config
    |> Tuple.to_list()
    |> List.flatten()
    |> Enum.find(& &1.source_for_headway?)
  end

  @spec single_source_config(Signs.Realtime.t()) :: SourceConfig.source() | nil
  defp single_source_config(sign) do
    case sign.source_config do
      {[one]} -> one
      _ -> nil
    end
  end
end
