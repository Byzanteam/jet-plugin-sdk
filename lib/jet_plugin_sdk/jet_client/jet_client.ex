defmodule JetPluginSDK.JetClient do
  @moduledoc false

  alias JetPluginSDK.GraphQLClient
  alias JetPluginSDK.Tenant

  @send_event_query """
  mutation SendEvent(
    $payload: PluginSendEventPayloadInput!
  ) {
    sendEvent(input: {
      payload: $payload
    }) {
      success
    }
  }
  """

  @type config() :: %{
          endpoint: String.t() | URI.t(),
          access_key: String.t()
        }

  @spec fetch_instance(Tenant.id()) ::
          {:ok, JetPluginSDK.TenantMan.Tenants.Tenant.instance()}
          | {:error, Req.Response.t() | GraphQLClient.error()}
  def fetch_instance(tenant_id) do
    {pid, eid, iid} = Tenant.split_tenant_id(tenant_id)
    variables = %{"projectId" => pid, "environmentId" => eid, "id" => iid}

    instance_query = """
    query Instance (
      $projectId: String!
      $environmentId: String!
      $id: String!
    ) {
      instance(
        projectId: $projectId,
        environmentId: $environmentId,
        id: $id
      ) {
        config
        capabilities {
          __typename
          ... on PluginInstanceCapabilityDatabase {
            schema
            databaseUrl
          }
        }
      }
    }
    """

    with {:ok, response} <- query(instance_query, variables, build_config()),
         {:ok, config} <- fetch_data(response, ["data", "instance", "config"]),
         {:ok, capabilities} <- fetch_data(response, ["data", "instance", "capabilities"]),
         {:ok, config} <- Jason.decode(config) do
      {:ok, %{config: config, capabilities: capabilities}}
    end
  end

  @spec list_instances() ::
          {:ok, [JetPluginSDK.TenantMan.WarmUp.instance()]}
          | {:error, Req.Response.t() | GraphQLClient.error()}
  def list_instances do
    instances_query = """
    query Instances {
      instances {
        projectId
        environmentId
        id
        state
      }
    }
    """

    with {:ok, response} <- query(instances_query, build_config()),
         {:ok, instances} <- fetch_data(response, ["data", "instances"]) do
      {:ok, build_instances(instances)}
    end
  end

  @spec send_event(payload :: map()) :: :ok | {:error, GraphQLClient.error()}
  def send_event(payload) do
    variables = %{"payload" => payload}

    case query(@send_event_query, variables, build_config()) do
      {:ok, %Req.Response{}} -> :ok
      otherwise -> otherwise
    end
  end

  @deprecated "fetch database infomation from tenant instead."
  @spec fetch_tenant_database(Tenant.id(), config()) ::
          {:ok, [capability :: map()]} | {:error, Req.Response.t()} | GraphQLClient.error()
  def fetch_tenant_database(tenant_id, config) do
    {project_id, env_id, instance_id} = Tenant.split_tenant_id(tenant_id)
    variables = %{"projectId" => project_id, "environmentId" => env_id, "id" => instance_id}

    instance_query = """
    query Instance(
      $projectId: String!
      $environmentId: String!
      $id: String!
    ) {
      instance(
        projectId: $projectId,
        environmentId: $environmentId,
        id: $id
      ) {
        capabilities {
          __typename
          ... on PluginInstanceCapabilityDatabase {
            schema
            databaseUrl
          }
        }
      }
    }
    """

    with {:ok, response} <- query(instance_query, variables, config) do
      fetch_data(response, ["data", "instance", "capabilities"])
    end
  end

  @spec build_config() :: config()
  defp build_config do
    :jet_plugin_sdk
    |> Application.get_env(__MODULE__, [])
    |> Map.new()
  end

  defp build_instances(instances) do
    Enum.map(instances, fn instance ->
      %{
        "projectId" => project_id,
        "environmentId" => environment_id,
        "id" => id,
        "state" => state
      } = instance

      %{
        tenant_id: Tenant.build_tenant_id(project_id, environment_id, id),
        state: state
      }
    end)
  end

  defp fetch_data(response, path) do
    if Map.has_key?(response.body, "errors") do
      {:error, response}
    else
      {:ok, get_in(response.body, path)}
    end
  end

  defp query(doc, variables \\ %{}, config) do
    JetPluginSDK.GraphQLClient.query(config.endpoint, doc,
      headers: [{"x-jet-plugin-access-key", config.access_key}],
      variables: variables
    )
  end
end
