defmodule JetPluginSDK.TenantMan.Tenants.Supervisor do
  @moduledoc false

  @compile {:inline, supervisor_name: 1}

  use DynamicSupervisor

  alias JetPluginSDK.TenantMan.Registry

  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()
  @typep tenant() :: JetPluginSDK.Tenant.t()

  @spec start_tenant(tenant_module(), tenant()) :: DynamicSupervisor.on_start_child()
  def start_tenant(tenant_module, tenant) do
    args = [
      name: Registry.name(tenant_module, tenant.id),
      tenant_module: tenant_module,
      tenant_id: tenant.id
    ]

    DynamicSupervisor.start_child(
      supervisor_name(tenant_module),
      {JetPluginSDK.TenantMan.Tenants.Tenant, args}
    )
  end

  @spec start_link(tenant_module: tenant_module()) :: Supervisor.on_start()
  def start_link(args) do
    tenant_module = Keyword.fetch!(args, :tenant_module)
    jet_client = Keyword.fetch!(args, :jet_client)

    DynamicSupervisor.start_link(
      __MODULE__,
      [tenant_module: tenant_module, jet_client: jet_client],
      name: supervisor_name(tenant_module)
    )
  end

  @impl DynamicSupervisor
  def init(init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [init_arg])
  end

  defp supervisor_name(tenant_module), do: Module.concat(tenant_module, TenantsSupervisor)
end
