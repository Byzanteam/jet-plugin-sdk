defmodule JetPluginSDK.TenantMan.Tenants.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  alias JetPluginSDK.TenantMan.Registry

  @type start_tenant_opts() :: [
          fetch_instance:
            (JetPluginSDK.Tenant.id() ->
               {:ok, JetPluginSDK.TenantMan.Tenants.Tenant.instance()}
               | {:error, term()})
        ]
  @spec start_tenant(
          tenant_module :: module(),
          tenant :: JetPluginSDK.Tenant.t(),
          start_tenant_opts()
        ) ::
          DynamicSupervisor.on_start_child()
  def start_tenant(tenant_module, tenant, opts \\ []) do
    args =
      Keyword.merge(opts,
        name: Registry.name(tenant_module, tenant.id),
        tenant: tenant,
        tenant_module: tenant_module
      )

    DynamicSupervisor.start_child(__MODULE__, {JetPluginSDK.TenantMan.Tenants.Tenant, args})
  end

  @spec start_link(args :: keyword()) :: Supervisor.on_start()
  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
