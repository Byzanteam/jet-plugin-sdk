defmodule JetPluginSDK.Support.Tenant.ValidateConfig do
  @moduledoc false

  use JetPluginSDK.TenantMan.Tenants.Tenant

  alias JetPluginSDK.Tenant, as: TenantSchema

  @enforce_keys [:tenant_id, :config]
  defstruct [
    :tenant_id,
    :config
  ]

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def init(%TenantSchema{} = tenant) do
    case cast_config(tenant.config) do
      %{errors: []} ->
        {:ok, tenant, %__MODULE__{tenant_id: tenant.id, config: tenant.config}}

      %{errors: errors} ->
        {:stop, {:invalid_config, errors}}
    end
  end

  @impl JetPluginSDK.TenantMan.Tenants.Tenant
  def handle_config_updation(new_config, _from, state) do
    case cast_config(new_config) do
      %{errors: []} ->
        {:reply, {:ok, new_config}, new_config, %{state | config: new_config}}

      %{errors: errors} ->
        {:reply, {:error, errors}, state.config, state}
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
