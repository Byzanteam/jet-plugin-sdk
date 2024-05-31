defmodule JetPluginSDK.Support.Tenant.Naive do
  @moduledoc false

  use JetPluginSDK.TenantMan

  @impl JetPluginSDK.TenantMan
  def handle_install(tenant) do
    if pid = Map.get(tenant.config, :pid), do: send(pid, {:handle_install, self()})

    if tenant.config.name === "error" do
      {:error, :install_failed}
    else
      {:ok, %{}}
    end
  end

  @impl JetPluginSDK.TenantMan
  def handle_run({_tenant, tenant_state}) do
    {:ok, tenant_state}
  end

  @impl JetPluginSDK.TenantMan
  def handle_update({config, _capabilities}, {_tenant, state}) do
    if config.name === "error" do
      {:error, :update_failed}
    else
      {:ok, state}
    end
  end

  @impl JetPluginSDK.TenantMan
  def handle_uninstall({tenant, state}) do
    if tenant.config.name === "uninstall" do
      {:error, :uninstall_failed}
    else
      {:ok, state}
    end
  end
end
