defmodule TelemetryAsync.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_async,
      version: "0.0.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 0.4.0"}
    ]
  end
end
