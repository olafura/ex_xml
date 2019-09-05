defmodule ExXml.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_xml,
      version: "0.1.3",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir Xml library that work similar to JSX",
      package: package(),
      dialyzer: dialyzer(System.get_env("CI"))
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
      {:nimble_parsec, "~> 0.5"},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false}
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

  defp dialyzer(nil) do
    [
      plt_add_apps: [:mix, :ex_unit],
      check_plt: true
    ]
  end

  defp dialyzer(_) do
    [
      plt_add_apps: [:mix, :ex_unit],
      check_plt: true,
      plt_file: {:no_warn, "priv/plts/ex_xml.plt"}
    ]
  end
end
