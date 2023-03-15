Application.ensure_all_started(:inets)
ExUnit.start()

Mox.defmock(Engine.NetworkCheck.Mock, for: Engine.NetworkCheck)
Mox.defmock(PaEss.Updater.Mock, for: PaEss.Updater)
