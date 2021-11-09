defmodule RealtimeSigns.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :realtime_signs,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: LcovEx],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix, :hackney, :httpd, :inets],
        plt_add_deps: true,
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      releases: [
        realtime_signs: [
          include_executables_for: [:windows],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger
      ],
      mod: {RealtimeSigns, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ehmon, git: "https://github.com/mbta/ehmon.git"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws, "~> 2.0"},
      {:lcov_ex, "~> 0.2", only: [:dev, :test], runtime: false},
      {:hackney, "== 1.18.0"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.2.0"},
      {:logger_splunk_backend, "~> 2.0"},
      {:mox, "~> 1.0.0", only: [:test]},
      {:sentry, "~> 8.0"},
      {:recon, "~> 2.5"},
      {:stream_data, "~> 0.1", only: [:dev, :test]},
      {:timex, "~> 3.1"},
      {:uuid, "~> 1.1", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
