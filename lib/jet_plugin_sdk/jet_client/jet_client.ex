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

  @spec list_instances() ::
          {:ok, [Tenant.t()]}
          | {:error, Req.Response.t() | GraphQLClient.error()}
  def list_instances do
    instances_query = """
    query Instances {
      instances {
        projectId
        environmentId
        id
        state
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
        "state" => state,
        "config" => config,
        "capabilities" => capabilities
      } = instance

      %Tenant{
        id: Tenant.build_tenant_id(project_id, environment_id, id),
        state: normalize_state(state),
        config: Jason.decode!(config),
        capabilities: normalize_capabilities(capabilities)
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

  defp normalize_state("PENDING"), do: :pending
  defp normalize_state("INSTALLING"), do: :installing
  defp normalize_state("RUNNING"), do: :running
  defp normalize_state("UPDATING"), do: :updating
  defp normalize_state("UNINSTALLING"), do: :uninstalling
  defp normalize_state("ERROR_OCCURRED"), do: :error_occurred

  defp normalize_capabilities(capabilities) do
    capabilities
    |> Enum.filter(fn capability ->
      Map.get(capability, "__typename") == "PluginInstanceCapabilityDatabase"
    end)
    |> Enum.map(fn capability ->
      JetPluginSDK.DatabaseCapability.from_map(capability)
    end)
  end
end
