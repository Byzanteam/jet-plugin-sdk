defmodule JetPluginSDK.Support.Tenant.Warmup do
  @moduledoc false

  use JetPluginSDK.TenantMan

  @impl JetPluginSDK.TenantMan
  def handle_install(_tenant) do
    {:ok, %{}}
  end

  @impl JetPluginSDK.TenantMan
  def handle_run({tenant, tenant_state}) do
    if tenant.config.runnable do
      send(tenant.config.pid, {:handle_run, tenant.id})
      {:ok, tenant_state}
    else
      send(tenant.config.pid, {:not_runnable, tenant.id})
      {:error, :not_runnable, tenant_state}
    end
  end
end
