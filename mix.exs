defmodule ExXml.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_xml,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir Xml library that work similar to JSX",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 0.5"}
    ]
  end

  defp package do
    [
      maintainers: ["Olafur Arason"],
      licenses: ["Apache-2.0"],
      links: %{github: "https://github.com/olafura/ex_xml"},
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end
end
