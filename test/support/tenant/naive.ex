defmodule JetPluginSDK.Support.Tenant.Naive do
  @moduledoc false

  use JetPluginSDK.TenantMan.Tenants.Tenant

  @enforce_keys [:tenant_id, :config]
  defstruct [:tenant_id, :config]

  def ping(server) do
    GenServer.call(server, :ping)
  end

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_install(_tenant) do
    {:ok, %{}}
  end

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_run({_tenant, tenant_state}) do
    {:noreply, tenant_state}
  end

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end
