import Config

config :logger,
  backends: [:console]

config :realtime_signs,
  # This flag enables testing of the in-progress bus work. It should be removed when the work
  # is finished
  test_bus_mode: System.get_env("TEST_BUS_MODE") == "true"
