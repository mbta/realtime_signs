defmodule RealtimeSigns.Mixfile do
  use Mix.Project

  def project do
    [
      app: :realtime_signs,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :exprotobuf,
        :httpoison,
        :logger,
        :poison,
        :sentry,
        :timex
      ],
      mod: {RealtimeSigns, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 0.5"},
      {:exprotobuf, github: "paulswartz/exprotobuf", ref: "ps-dialyzer", override: true},
      {:hackney, "== 1.8.0", override: true},
      {:httpoison, "~> 0.11.0"},
      {:poison, "~> 2.0"},
      {:sentry, "~> 6.0.0"},
      {:timex, "~> 3.1.0"}
    ]
  end
end
