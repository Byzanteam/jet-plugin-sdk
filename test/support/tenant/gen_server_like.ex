defmodule JetPluginSDK.Support.Tenant.GenServerLike do
  @moduledoc false

  use JetPluginSDK.TenantMan

  @impl JetPluginSDK.TenantMan
  def handle_install(_tenant) do
    {:ok, %{}}
  end

  @impl JetPluginSDK.TenantMan
  def handle_run({_tenant, tenant_state}) do
    {:ok, tenant_state}
  end

  @impl JetPluginSDK.TenantMan
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end
