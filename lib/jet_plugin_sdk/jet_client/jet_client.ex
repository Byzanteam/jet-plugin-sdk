defmodule JetPluginSDK.JetClient do
  @moduledoc false

  alias JetPluginSDK.GraphQLClient
  alias JetPluginSDK.Tenant

  @type config() :: %{
          endpoint: String.t() | URI.t(),
          access_key: String.t()
        }

  defp query(doc, variables \\ %{}, config) do
    JetPluginSDK.GraphQLClient.query(config.endpoint, doc,
      headers: [{"x-jet-plugin-access-key", config.access_key}],
      variables: variables
    )
  end

  @type instance() :: %{
          tenant_id: Tenant.id(),
          project_id: String.t(),
          environment_id: String.t(),
          id: String.t(),
          config: nil | map(),
          capabilities: [map()],
          state: String.t()
        }

  @spec fetch_instances(config()) ::
          {:ok, [instance()]} | {:error, Req.Response.t()} | GraphQLClient.error()
  def fetch_instances(config) do
    instances_query = """
    {
      instances {
        projectId
        environmentId
        id
        config
        capabilities {
          __typename
          ... on PluginInstanceCapabilityDatabase {
            schema
            databaseUrl
          }
        }
        state
      }
    }
    """

    case query(instances_query, config) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body |> get_in(["data", "instances"]) |> build_instances()}

      {:ok, resp} ->
        {:error, resp}

      otherwise ->
        otherwise
    end
  end

  defp build_instances(instances) do
    Enum.map(instances, fn instance ->
      %{
        "projectId" => project_id,
        "environmentId" => environment_id,
        "id" => id,
        "config" => config,
        "capabilities" => capabilities,
        "state" => state
      } = instance

      %{
        tenant_id: Tenant.build_tenant_id(project_id, environment_id, id),
        project_id: project_id,
        environment_id: environment_id,
        id: id,
        config: config && Jason.decode!(config),
        capabilities: capabilities,
        state: state
      }
    end)
  end

  @spec fetch_tenant_database(Tenant.id(), config()) ::
          {:ok, [capability :: map()]} | {:error, Req.Response.t()} | GraphQLClient.error()
  def fetch_tenant_database(tenant_id, config) do
    {project_id, env_id, instance_id} = Tenant.split_tenant_id(tenant_id)

    instance_query = """
    query instance(
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

    variables = %{"projectId" => project_id, "environmentId" => env_id, "id" => instance_id}

    case query(instance_query, variables, config) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, get_in(body, ["data", "instance", "capabilities"])}

      {:ok, resp} ->
        {:error, resp}

      otherwise ->
        otherwise
    end
  end

  @send_event_query """
  mutation sendEvent(
    $payload: PluginSendEventPayloadInput!
  ) {
    sendEvent(input: {
      payload: $payload
    }) {
      success
    }
  }
  """

  @spec send_event(payload :: map(), config :: config()) :: :ok | {:error, GraphQLClient.error()}
  def send_event(payload, config) do
    variables = %{"payload" => payload}

    case query(@send_event_query, variables, config) do
      {:ok, %Req.Response{}} -> :ok
      otherwise -> otherwise
    end
  end

  @spec build_config() :: config()
  def build_config do
    :jet_plugin_sdk
    |> Application.get_env(__MODULE__, [])
    |> Map.new()
  end
end
