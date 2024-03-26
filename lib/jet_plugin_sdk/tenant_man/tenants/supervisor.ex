defmodule JetPluginSDK.TenantMan.Tenants.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  alias JetPluginSDK.TenantMan.Registry

  @spec start_tenant(tenant_module :: module(), tenant :: JetPluginSDK.Tenant.t()) ::
          DynamicSupervisor.on_start_child()
  def start_tenant(tenant_module, tenant) do
    args = [name: Registry.name(tenant_module, tenant.id), tenant: tenant]

    DynamicSupervisor.start_child(__MODULE__, {tenant_module, args})
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
