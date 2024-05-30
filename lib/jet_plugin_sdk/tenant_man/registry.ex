defmodule JetPluginSDK.TenantMan.Registry do
  @moduledoc false

  @compile {:inline, registry_name: 1}

  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()
  @typep tenant_id() :: JetPluginSDK.Tenant.id()

  @spec child_spec(opts :: [tenant_module: tenant_module()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    tenant_module = Keyword.fetch!(opts, :tenant_module)

    Supervisor.child_spec({Registry, keys: :unique, name: registry_name(tenant_module)}, [])
  end

  @spec name(tenant_module(), tenant_id()) :: GenServer.name()
  def name(tenant_module, tenant_id) do
    {:via, Registry, {registry_name(tenant_module), tenant_id}}
  end

  @spec whereis(tenant_module(), tenant_id()) :: {:ok, pid()} | :error
  def whereis(tenant_module, tenant_id) do
    case Registry.whereis_name({registry_name(tenant_module), tenant_id}) do
      :undefined -> :error
      pid -> {:ok, pid}
    end
  end

  defp registry_name(tenant_module), do: Module.concat(tenant_module, Registry)
end
