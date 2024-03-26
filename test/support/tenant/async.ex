defmodule JetPluginSDK.Support.Tenant.Async do
  @moduledoc false

  use JetPluginSDK.TenantMan.Tenants.Tenant

  @enforce_keys [:tenant_id, :config]
  defstruct [:tenant_id, :config]

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_install(tenant) do
    case cast_config(tenant.config) do
      %{errors: []} ->
        {:ok, %__MODULE__{tenant_id: tenant.id, config: tenant.config}}

      %{errors: errors} ->
        {:error, {:invalid_config, errors}}
    end
  end

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_run({_tenant, tenant_state}) do
    {:noreply, tenant_state}
  end

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_update(config, {_tenant, state}) do
    {:async, {__MODULE__, :update_async, [config, state]}}
  end

  def update_async(config, state) do
    case cast_config(config) do
      %{errors: []} ->
        {:ok, %{state | config: config}}

      %{errors: errors} ->
        {:error, errors}
    end
  end

  defp cast_config(config) do
    name = Map.get(config, :name)

    if is_nil(name) do
      %{changes: %{}, errors: [name: {"is invalid", validation: :required}]}
    else
      %{changes: %{name: name}, errors: []}
    end
  end
end
