defmodule JetPluginSDK.Tenant do
  @moduledoc false

  @type tenant_id() :: String.t()

  @spec build_tenant_id(
          project_id :: String.t(),
          environment_id :: String.t(),
          instance_id :: String.t()
        ) :: tenant_id()
  def build_tenant_id(project_id, environment_id, instance_id) do
    "#{project_id}_#{environment_id}_#{instance_id}"
  end

  @spec split_tenant_id(tenant_id()) ::
          {project_id :: String.t(), environment_id :: String.t(), instance_id :: String.t()}
  def split_tenant_id(tenant_id) do
    [project_id, environment_id, instance_id] = String.split(tenant_id, "_")
    {project_id, environment_id, instance_id}
  end
end
