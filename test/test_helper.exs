Application.ensure_all_started(:inets)
ExUnit.start()

Mox.defmock(Engine.NetworkCheck.Mock, for: Engine.NetworkCheck)
Mox.defmock(PaEss.Updater.Mock, for: PaEss.Updater)
Mox.defmock(Engine.Config.Mock, for: Engine.ConfigAPI)
Mox.defmock(Engine.Alerts.Mock, for: Engine.AlertsAPI)
Mox.defmock(Engine.Predictions.Mock, for: Engine.PredictionsAPI)
Mox.defmock(Engine.Locations.Mock, for: Engine.LocationsAPI)
