defmodule JetPluginSDK.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one, name: __MODULE__)
  end

  if Mix.env() === :test do
    def children, do: []
  else
    def children do
      args = Application.get_env(:jet_plugin_sdk, JetPluginSDK.TenantMan, [])

      [{JetPluginSDK.TenantMan.Supervisor, args}]
    end
  end
end
