defmodule Signs.Utilities.Headways do
  @moduledoc """
  Given a sign with a SourceConfig, fetches headways and
  geneartes the top and bottom lines for the sign
  """
  alias Signs.Utilities.SourceConfig

  @gl_gov_ctr_disruption_start ~N[2020-02-29 03:00:00]
  @gl_gov_ctr_disruption_end ~N[2020-03-02 03:00:00]
  @lechmere_destination_sign_ids ["green_north_station_eastbound", "science_park_eastbound"]
  @haymarket_destination_sign_ids [
    "lechmere_green_line",
    "science_park_westbound",
    "green_north_station_westbound"
  ]

  @spec get_messages(Signs.Realtime.t(), DateTime.t()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_messages(sign, current_time) do
    cond do
      config = single_source_config(sign) ->
        do_headway_messages(sign, config, current_time)

      config = config_by_headway_id(sign) ->
        do_headway_messages(sign, config, current_time)

      true ->
        {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end
  end

  @spec do_headway_messages(Signs.Realtime.t(), map(), DateTime.t()) ::
          {{map(), Content.Message.t()}, {map(), Content.Message.t()}}
  defp do_headway_messages(sign, config, current_time) do
    during_gl_gov_ctr_disruption? =
      DateTime.compare(
        current_time,
        Timex.to_datetime(@gl_gov_ctr_disruption_start, "America/New_York")
      ) == :gt and
        DateTime.compare(
          current_time,
          Timex.to_datetime(@gl_gov_ctr_disruption_end, "America/New_York")
        ) == :lt

    stop_id = sign.headway_stop_id || config.stop_id
    headway_range = sign.headway_engine.get_headways(stop_id)

    all_gl_changed_signs =
      Enum.concat(@haymarket_destination_sign_ids, @lechmere_destination_sign_ids)

    last_departure =
      if during_gl_gov_ctr_disruption? and sign.id in all_gl_changed_signs do
        nil
      else
        sign.last_departure_engine.get_last_departure(config.stop_id)
      end

    destination =
      cond do
        during_gl_gov_ctr_disruption? and sign.id in @haymarket_destination_sign_ids -> :haymarket
        during_gl_gov_ctr_disruption? and sign.id in @lechmere_destination_sign_ids -> :lechmere
        true -> config.headway_destination
      end

    case headway_range do
      :none ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {nil, nil} ->
        {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}

      {:first_departure, range, first_departure} ->
        max_headway = Headway.HeadwayDisplay.max_headway(range)
        time_buffer = if max_headway, do: max_headway, else: 0

        if Headway.HeadwayDisplay.show_first_departure?(
             first_departure,
             Timex.now(),
             time_buffer
           ) do
          {
            {config,
             %Content.Message.Headways.Top{
               destination: destination,
               vehicle_type: vehicle_type(config.routes)
             }},
            {config, %Content.Message.Headways.Bottom{range: range}}
          }
        else
          {{config, Content.Message.Empty.new()}, {config, Content.Message.Empty.new()}}
        end

      {bottom, top} ->
        {{config,
          %Content.Message.Headways.Top{
            destination: destination,
            vehicle_type: vehicle_type(config.routes)
          }},
         {config,
          %Content.Message.Headways.Bottom{
            range: {bottom, top},
            prev_departure_mins: minutes_ago(last_departure, current_time)
          }}}
    end
  end

  defp vehicle_type(["743"]), do: :bus
  defp vehicle_type(_), do: :train

  @spec config_by_headway_id(Signs.Realtime.t()) :: SourceConfig.source() | nil
  defp config_by_headway_id(sign) do
    sign.source_config
    |> Tuple.to_list()
    |> List.flatten()
    |> Enum.find(& &1.source_for_headway?)
  end

  defp single_source_config(sign) do
    case sign.source_config do
      {[one]} -> one
      _ -> nil
    end
  end

  @spec minutes_ago(DateTime.t() | nil, DateTime.t()) :: integer() | nil
  defp minutes_ago(nil, _current_time) do
    nil
  end

  defp minutes_ago(departure_time, current_time) do
    diff =
      current_time
      |> DateTime.diff(departure_time)

    if diff < 5 do
      0
    else
      diff
      |> Kernel./(60)
      |> Float.ceil()
      |> Kernel.trunc()
    end
  end
end
