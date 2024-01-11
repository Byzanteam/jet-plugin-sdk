defmodule JetPluginSDK.Support.Tenant.Naive do
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
    {:ok, tenant, %__MODULE__{tenant_id: tenant.id, config: tenant.config}}
  end
end
