defmodule RealtimeSigns.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :realtime_signs,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: LcovEx],
      elixirc_paths: elixirc_paths(Mix.env()),
      releases: [
        linux: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RealtimeSigns, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.12"},
      {:dialyxir, "~> 1.4.3", only: [:dev, :test], runtime: false},
      {:ehmon, git: "https://github.com/mbta/ehmon.git"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws, "~> 2.0"},
      {:lcov_ex, "~> 0.2", only: [:dev, :test], runtime: false},
      {:gen_stage, "~> 1.2"},
      {:logger_backends, "~> 1.0"},
      {:logger_splunk_backend, "~> 3.0"},
      {:mox, "~> 1.2.0", only: [:test]},
      {:recon, "~> 2.5"},
      {:req, "~> 0.6.0"},
      {:timex, "~> 3.1"},
      {:uuid, "~> 1.1", only: :test},
      {:quantum, "~> 3.0"},
      {:phoenix, "~> 1.8.7"},
      {:remote_ip, "~> 1.2"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
