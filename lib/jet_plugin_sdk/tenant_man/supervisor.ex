defmodule JetPluginSDK.TenantMan.Supervisor do
  @moduledoc false

  use Supervisor

  @typep naming_fun() :: JetPluginSDK.TenantMan.naming_fun()
  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()

  @spec start_link(
          naming_fun: naming_fun(),
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
    naming_fun = Keyword.fetch!(opts, :naming_fun)
    tenant_module = Keyword.fetch!(opts, :tenant_module)

    children = [
      {JetPluginSDK.TenantMan.Registry, naming_fun: naming_fun},
      {JetPluginSDK.TenantMan.Storage, naming_fun: naming_fun, tenant_module: tenant_module},
      {
        JetPluginSDK.TenantMan.Tenants.Supervisor,
        naming_fun: naming_fun, tenant_module: tenant_module
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
