defmodule Signs.Utilities.SignPredictionInfo do
  @moduledoc false

  @enforce_keys [
    :predictions,
    :all_predictions,
    :sign_config,
    :current_time,
    :alert_status,
    :first_scheduled_departures,
    :last_scheduled_departures,
    :recent_departures,
    :service_end_statuses_per_source
  ]
  defstruct @enforce_keys

  @type single_or_tuple(t) :: t | {t, t}
  @type t :: %__MODULE__{
          predictions: Signs.Realtime.predictions(),
          all_predictions: list(Predictions.Prediction.t()),
          sign_config: Engine.Config.sign_config(),
          current_time: DateTime.t(),
          alert_status: single_or_tuple(Engine.Alerts.Fetcher.stop_status()),
          first_scheduled_departures: single_or_tuple(nil | DateTime.t()),
          last_scheduled_departures: single_or_tuple(nil | DateTime.t()),
          recent_departures: single_or_tuple(nil | DateTime.t()),
          service_end_statuses_per_source: single_or_tuple(boolean())
        }
end
