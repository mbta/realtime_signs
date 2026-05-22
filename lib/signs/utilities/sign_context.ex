defmodule Signs.Utilities.SignContext do
  @moduledoc false

  defmodule ConfigContext do
    @enforce_keys [
      :config,
      :predictions,
      :alert_status,
      :headways,
      :first_scheduled_departure,
      :last_scheduled_departure,
      :most_recent_departure,
      :service_ended?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            config: Signs.Utilities.SourceConfig.config(),
            predictions: [Predictions.Prediction.t()],
            alert_status: Engine.Alerts.Fetcher.stop_status(),
            headways: Engine.Config.Headway.t() | nil,
            first_scheduled_departure: DateTime.t() | nil,
            last_scheduled_departure: DateTime.t() | nil,
            most_recent_departure: DateTime.t() | nil,
            service_ended?: boolean()
          }
  end

  @enforce_keys [:sign_config, :current_time, :config_contexts]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          sign_config: Engine.Config.sign_config(),
          current_time: DateTime.t(),
          config_contexts: [ConfigContext.t()]
        }
end
