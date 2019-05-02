defmodule TelemetryAsync.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :telemetry_async,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Async execution of BEAM telemetry events",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    []
  end

  defp package() do
    [
      maintainers: [
        "Steve Bussey"
      ],
      licenses: ["MIT"],
      links: %{github: "https://github.com/pushex-project/telemetry_async"},
      files: ~w(lib) ++ ~w(mix.exs README.md)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 0.4.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md"
      ]
    ]
  end
end
