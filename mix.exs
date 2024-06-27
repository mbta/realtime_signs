defmodule RealtimeSigns.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :realtime_signs,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: LcovEx],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix, :hackney, :httpd, :inets],
        plt_add_deps: :app_tree,
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
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
      extra_applications: [
        :logger
      ],
      mod: {RealtimeSigns, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4.3", only: [:dev, :test], runtime: false},
      {:ehmon, git: "https://github.com/mbta/ehmon.git"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws, "~> 2.0"},
      {:lcov_ex, "~> 0.2", only: [:dev, :test], runtime: false},
      {:hackney, "== 1.20.1"},
      {:gen_stage, "~> 1.2"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.4.0"},
      {:logger_splunk_backend, "~> 3.0"},
      {:mox, "~> 1.1.0", only: [:test]},
      {:sentry, "~> 8.0"},
      {:recon, "~> 2.5"},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:timex, "~> 3.1"},
      {:uuid, "~> 1.1", only: :test},
      {:quantum, "~> 3.0"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_view, "~> 2.0"},
      {:plug_cowboy, "~> 2.5"},
      {:configparser_ex, "~> 4.0", only: [:prod]},
      {:remote_ip, "~> 1.2"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
