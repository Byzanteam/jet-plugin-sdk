defmodule JetPluginSDK.Support.Tenant.Terminate do
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
  def terminate(reason, {tenant, _state}) do
    send(tenant.config.pid, {:tenant_terminated, tenant.id, reason})
  end
end
