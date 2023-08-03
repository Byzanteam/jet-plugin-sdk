defmodule JetPluginSdk.MixProject do
  use Mix.Project

  def project do
    [
      app: :jet_plugin_sdk,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :absinthe]
      ],
      aliases: aliases()
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:absinthe, "~> 1.7"},
      {:joken, "~> 2.6"},
      {:plug, "~> 1.14"}
    ]
  end

  defp aliases do
    [
      "code.check": ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end
end
