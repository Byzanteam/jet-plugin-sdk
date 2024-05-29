defmodule JetPluginSDK.TenantMan.Tenants.Supervisor do
  @moduledoc false

  @compile {:inline, supervisor_name: 1}

  use DynamicSupervisor

  alias JetPluginSDK.TenantMan.Registry

  @typep naming_fun() :: JetPluginSDK.TenantMan.naming_fun()
  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()
  @typep tenant() :: JetPluginSDK.Tenant.t()

  @spec start_tenant(naming_fun(), tenant()) :: DynamicSupervisor.on_start_child()
  def start_tenant(naming_fun, tenant) do
    args = [
      name: Registry.name(naming_fun, tenant.id),
      naming_fun: naming_fun,
      tenant_id: tenant.id
    ]

    DynamicSupervisor.start_child(
      supervisor_name(naming_fun),
      {JetPluginSDK.TenantMan.Tenants.Tenant, args}
    )
  end

  @spec start_link(naming_fun: naming_fun(), tenant_module: tenant_module()) ::
          Supervisor.on_start()
  def start_link(args) do
    tenant_module = Keyword.fetch!(args, :tenant_module)
    naming_fun = Keyword.fetch!(args, :naming_fun)

    DynamicSupervisor.start_link(
      __MODULE__,
      [naming_fun: naming_fun, tenant_module: tenant_module],
      name: supervisor_name(naming_fun)
    )
  end

  @impl DynamicSupervisor
  def init(init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [init_arg])
  end

  defp supervisor_name(naming_fun), do: naming_fun.(:tenants_supervisor)
end
