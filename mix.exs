defmodule Assistant.MixProject do
  use Mix.Project

  def project do
    [
      app: :assistant,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        assistant: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Assistant, []}
    ]
  end

  defp deps do
    [{:tesla, "~> 1.2.1"}, {:hackney, "~> 1.10"}, {:jason, ">= 1.0.0"}]
  end
end
