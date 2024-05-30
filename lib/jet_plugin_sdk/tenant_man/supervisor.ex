defmodule JetPluginSDK.TenantMan.Supervisor do
  @moduledoc false

  use Supervisor

  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()

  @spec start_link(
          tenant_module: tenant_module(),
          name: GenServer.name()
        ) ::
          Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop!(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    tenant_module = Keyword.fetch!(opts, :tenant_module)
    jet_client = Keyword.fetch!(opts, :jet_client)

    children = [
      {JetPluginSDK.TenantMan.Registry, tenant_module: tenant_module},
      {
        JetPluginSDK.TenantMan.Storage,
        tenant_module: tenant_module, jet_client: jet_client
      },
      {
        JetPluginSDK.TenantMan.Tenants.Supervisor,
        tenant_module: tenant_module, jet_client: jet_client
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
