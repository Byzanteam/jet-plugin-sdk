defmodule JetPluginSDK.MixProject do
  use Mix.Project

  def project do
    [
      app: :jet_plugin_sdk,
      version: "0.1.0",
      name: "JetPluginSDK",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :absinthe]
      ],
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      mod: {JetPluginSDK.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:absinthe_client, "~> 0.1.0"},
      {:joken, "~> 2.6"},
      {:plug, "~> 1.14"},
      {:req, "~> 0.5.0", override: true},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mimic, "~> 1.7", only: :test}
    ]
  end

  defp aliases do
    [
      "code.check": ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
