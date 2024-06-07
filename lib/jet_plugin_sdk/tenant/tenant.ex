defmodule JetPluginSDK.Tenant do
  @moduledoc false

  @type id() :: String.t()
  @type config() :: JetPluginSDK.Tenant.Config.t()
  @type capabilities() :: [JetPluginSDK.Tenant.Capability.t()]
  @type state() ::
          :pending
          | :installing
          | :running
          | :updating
          | :uninstalling
          | :error_occurred
          | :uninstalled

  @enforce_keys [:id, :state, :config, :capabilities]

  defstruct [:id, :state, :config, :capabilities]

  @delimiter "_"

  @type t() :: %__MODULE__{
          id: id(),
          config: config(),
          capabilities: capabilities(),
          state: state()
        }

  # credo:disable-for-next-line Credo.Check.Design.TagFIXME
  # FIXME: https://github.com/Byzanteam/jet-plugin-sdk/pull/58#discussion_r1623729157
  @spec build_tenant_id(%{
          optional(:config) => config(),
          optional(:capabilities) => capabilities(),
          project_id: String.t(),
          env_id: String.t(),
          instance_id: String.t()
        }) ::
          id()
  def build_tenant_id(%{project_id: project_id, env_id: env_id, instance_id: instance_id}) do
    build_tenant_id(project_id, env_id, instance_id)
  end

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
