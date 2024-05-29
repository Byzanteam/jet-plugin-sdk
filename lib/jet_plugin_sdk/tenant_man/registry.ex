defmodule JetPluginSDK.TenantMan.Registry do
  @moduledoc false

  @compile {:inline, registry_name: 1}

  @typep naming_fun() :: JetPluginSDK.TenantMan.naming_fun()
  @typep tenant_id() :: JetPluginSDK.Tenant.id()

  @spec child_spec(opts :: [naming_fun: naming_fun()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    naming_fun = Keyword.fetch!(opts, :naming_fun)

    Supervisor.child_spec({Registry, keys: :unique, name: registry_name(naming_fun)}, [])
  end

  @spec name(naming_fun(), tenant_id()) :: GenServer.name()
  def name(naming_fun, tenant_id) do
    {:via, Registry, {registry_name(naming_fun), tenant_id}}
  end

  @spec whereis(naming_fun(), tenant_id()) :: {:ok, pid()} | :error
  def whereis(naming_fun, tenant_id) do
    case Registry.whereis_name({registry_name(naming_fun), tenant_id}) do
      :undefined -> :error
      pid -> {:ok, pid}
    end
  end

  defp registry_name(naming_fun), do: naming_fun.(:registry)
end
