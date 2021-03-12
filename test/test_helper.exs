Application.ensure_all_started(:inets)
ExUnit.start()

Mox.defmock(Engine.NetworkCheck.Mock, for: Engine.NetworkCheck)
