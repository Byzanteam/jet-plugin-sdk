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

  @spec fetch_data(Req.Response.t(), list(String.t())) ::
          {:ok, term()} | {:error, Req.Response.t()}
  defp fetch_data(response, path) do
    with(
      :error <- fetch_in_map(response.body, ["errors"]),
      {:ok, data} <- fetch_in_map(response.body, path)
    ) do
      {:ok, data}
    else
      _otherwise -> {:error, response}
    end
  end

  @spec fetch_in_map(term(), list(String.t())) :: {:ok, term()} | :error
  defp fetch_in_map(data, []), do: {:ok, data}

  defp fetch_in_map(data, [key | rest]) when is_map(data) do
    case Map.fetch(data, key) do
      :error -> :error
      {:ok, value} -> fetch_in_map(value, rest)
    end
  end

  defp fetch_in_map(_data, _path), do: :error

  @spec query(String.t(), map(), config()) ::
          {:ok, Req.Response.t()} | {:error, GraphQLClient.error()}
  defp query(doc, variables \\ %{}, config) do
    JetPluginSDK.GraphQLClient.query(config.endpoint, doc,
      headers: [{"x-jet-plugin-access-key", config.access_key}],
      variables: variables
    )
  end
end
