defmodule JetPluginSDK.TenantMan.Supervisor do
  @moduledoc false

  use Supervisor

  @spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      JetPluginSDK.TenantMan.Registry,
      JetPluginSDK.TenantMan.Tenants.Supervisor
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
