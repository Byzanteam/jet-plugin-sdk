defmodule JetPluginSDK.Support.Tenant.GenServerLike do
  @moduledoc false

  use JetPluginSDK.TenantMan.Tenants.Tenant

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
