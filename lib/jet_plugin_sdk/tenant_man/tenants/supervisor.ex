defmodule JetPluginSDK.TenantMan.Tenants.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  alias JetPluginSDK.TenantMan.Tenants.Tenant

  @spec name() :: __MODULE__
  def name, do: __MODULE__

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, [], name: name())
  end

  @spec start_tenant(
          tenant_id :: JetPluginSDK.Tenant.tenant_id(),
          tenant_module :: module(),
          tenant :: JetPluginSDK.Tenant.t()
        ) :: {:ok, pid()} | {:error, term()}
  def start_tenant(tenant_id, tenant_module, tenant) do
    args = [
      tenant_id: tenant_id,
      tenant: tenant
    ]

    tenant_name = Tenant.name(tenant_module, tenant_id)

    JetPluginSDK.TenantMan.Registry.start_child(tenant_name, name(), {tenant_module, args})
  end

  @spec whereis_tenant(
          tenant_id :: JetPluginSDK.Tenant.tenant_id(),
          tenant_module :: module()
        ) :: {:ok, pid()} | :error
  def whereis_tenant(tenant_id, tenant_module) do
    tenant_name = Tenant.name(tenant_module, tenant_id)
    JetPluginSDK.TenantMan.Registry.whereis_name(tenant_name)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
