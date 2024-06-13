defmodule JetPluginSDK.MixProject do
  use Mix.Project

  def project do
    [
      app: :jet_plugin_sdk,
      version: "0.1.2",
      name: "JetPluginSDK",
      elixir: "~> 1.14",
      description: "The Jet Plugin SDK",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [
        name: "jet_plugin_sdk",
        licenses: ["MIT"],
        files: ~w(lib mix.exs mix.lock .tool-versions README.md),
        links: %{
          "GitHub" => "https://github.com/Byzanteam/jet-plugin-sdk"
        }
      ],
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :absinthe]
      ],
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:joken, "~> 2.6"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mimic, "~> 1.7", only: :test},
      {:jet_ext, "~> 0.2.0"}
    ]
  end

  defp docs do
    [
      main: "Ecto",
      groups_for_docs: [
        {"Life-cycle callbacks", &(&1[:group] == "Life-cycle callbacks")},
        {"GenServer callbacks", &(&1[:group] == "GenServer callbacks")}
      ],
      groups_for_modules: [
        "Life-cycle callbacks": [
          JetPluginSDK.TenantMan
        ],
        "GenServer callbacks": [
          JetPluginSDK.TenantMan
        ]
      ]
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
