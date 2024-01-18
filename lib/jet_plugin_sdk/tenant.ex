defmodule JetPluginSDK.Tenant do
  @moduledoc false

  @type tenant_id() :: String.t()
  @type config() :: nil | map()

  @enforce_keys [:id, :state]

  @tenant_key :jet_plugin_tenant

  defstruct [
    :id,
    :config,
    :state,
    capabilities: []
  ]

  @type t() :: %__MODULE__{
          id: tenant_id(),
          config: config(),
          capabilities: [map()],
          state: :enabled | :disabled
        }

  @spec assign_tenant(conn :: conn, tenant :: map()) :: conn when conn: Plug.Conn.t()
  def assign_tenant(conn, tenant) do
    Plug.Conn.put_private(conn, @tenant_key, tenant)
  end

  @spec build_tenant_id(
          project_id :: String.t(),
          environment_id :: String.t(),
          instance_id :: String.t()
        ) :: tenant_id()
  def build_tenant_id(project_id, environment_id, instance_id) do
    "#{project_id}_#{environment_id}_#{instance_id}"
  end

  @spec fetch_tenant(conn :: Plug.Conn.t()) :: {:ok, map()} | :error
  def fetch_tenant(conn) do
    Map.fetch(conn.private, @tenant_key)
  end

  @spec split_tenant_id(tenant_id()) ::
          {project_id :: String.t(), environment_id :: String.t(), instance_id :: String.t()}
  def split_tenant_id(tenant_id) do
    [project_id, environment_id, instance_id] = String.split(tenant_id, "_")
    {project_id, environment_id, instance_id}
  end
end
