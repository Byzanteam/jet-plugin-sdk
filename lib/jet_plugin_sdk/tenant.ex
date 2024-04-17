defmodule JetPluginSDK.Tenant do
  @moduledoc false

  @type id() :: String.t()
  @type config() :: map()
  @type capabilities() :: [map()]

  @enforce_keys [:id, :state]

  @delimiter "_"

  defstruct [
    :id,
    :config,
    :state,
    capabilities: []
  ]

  @type t() :: %__MODULE__{
          id: id(),
          config: config(),
          capabilities: [map()],
          state: :installing | :running | :updating
        }

  @spec build_tenant_id(
          project_id :: String.t(),
          environment_id :: String.t(),
          instance_id :: String.t()
        ) :: id()
  def build_tenant_id(project_id, environment_id, instance_id) do
    Enum.join([project_id, environment_id, instance_id], @delimiter)
  end

  @spec split_tenant_id(id()) ::
          {project_id :: String.t(), environment_id :: String.t(), instance_id :: String.t()}
  def split_tenant_id(tenant_id) do
    [project_id, environment_id, instance_id] = String.split(tenant_id, @delimiter)
    {project_id, environment_id, instance_id}
  end
end
