defmodule JetPluginSDK.Support.Tenant.Async do
  @moduledoc false

  use JetPluginSDK.TenantMan

  @spec fetch_tenant(JetPluginSDK.Tenant.id()) :: term()
  def fetch_tenant(tenant_id) do
    {:ok, pid} = whereis(tenant_id)
    GenServer.call(pid, :fetch)
  end

  @impl JetPluginSDK.TenantMan
  def handle_install(tenant) do
    {:async, {__MODULE__, :install_async, [tenant]}}
  end

  @impl JetPluginSDK.TenantMan
  def handle_run({_tenant, tenant_state}) do
    {:ok, tenant_state}
  end

  @impl JetPluginSDK.TenantMan
  def handle_update({config, capabilities}, {_tenant, state}) do
    {:async, {__MODULE__, :update_async, [config, capabilities, state]}}
  end

  @impl JetPluginSDK.TenantMan
  def handle_uninstall({tenant, state}) do
    {:async, {__MODULE__, :uninstall_async, [tenant, state]}}
  end

  @impl JetPluginSDK.TenantMan
  def handle_call(:fetch, _from, {tenant, state}) do
    {:reply, tenant, state}
  end

  @spec install_async(JetPluginSDK.Tenant.t()) :: {:ok, term()} | {:error, :install_failed}
  def install_async(tenant) do
    if tenant.config.name === "error" do
      {:error, :install_failed}
    else
      {:ok, %{}}
    end
  end

  @spec update_async(JetPluginSDK.Tenant.config(), JetPluginSDK.Tenant.capabilities(), term()) ::
          {:ok, term()} | {:error, :update_failed}
  def update_async(config, _capablities, state) do
    if config.name === "update" do
      {:error, :update_failed}
    else
      {:ok, state}
    end
  end

  @spec uninstall_async(JetPluginSDK.Tenant.t(), term()) ::
          {:ok, term()} | {:error, :uninstall_failed}
  def uninstall_async(tenant, state) do
    if tenant.config.name === "uninstall" do
      {:error, :uninstall_failed}
    else
      {:ok, state}
    end
  end
end
