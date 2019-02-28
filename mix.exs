defmodule RealtimeSigns.Mixfile do
  use Mix.Project

  def project do
    [
      app: :realtime_signs,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: true,
        ignore_warnings: ".dialyzer.ignore-warnings"
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
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:ehmon, git: "https://github.com/heroku/ehmon.git", tag: "v4"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:excoveralls, "~> 0.5", only: :test},
      {:exprotobuf, "~> 1.0"},
      {:httpoison, "~> 1.0"},
      {:logger_splunk_backend, git: "https://github.com/mbta/logger_splunk_backend.git"},
      {:poison, "~> 3.1"},
      {:sentry, "~> 6.2"},
      {:timex, "~> 3.1"}
    ]
  end
end
