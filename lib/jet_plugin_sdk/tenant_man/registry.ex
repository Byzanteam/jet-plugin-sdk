defmodule JetPluginSDK.TenantMan.Registry do
  @moduledoc false

  alias JetPluginSDK.Tenant

  @type name() :: GenServer.name()

  @spec name(tenant_module :: module(), tenant_id :: Tenant.id()) :: name()
  def name(tenant_module, tenant_id) do
    {:via, Registry, {__MODULE__, {tenant_module, tenant_id}}}
  end

  @spec whereis(tenant_module :: module(), tenant_id :: Tenant.id()) :: {:ok, pid()} | :error
  def whereis(tenant_module, tenant_id) do
    case Registry.whereis_name({__MODULE__, {tenant_module, tenant_id}}) do
      :undefined -> :error
      pid -> {:ok, pid}
    end
  end

  @spec child_spec(opts :: keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    Supervisor.child_spec({Registry, name: __MODULE__, keys: :unique}, opts)
  end
end
