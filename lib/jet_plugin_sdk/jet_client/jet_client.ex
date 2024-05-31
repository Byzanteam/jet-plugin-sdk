defmodule JetPluginSDK.JetClient do
  @moduledoc false

  @enforce_keys [:endpoint, :access_key]
  defstruct [:endpoint, :access_key]

  @type t() :: %__MODULE__{
          endpoint: String.t(),
          access_key: String.t()
        }

  @spec new() :: t()
  def new do
    __struct__(Application.fetch_env!(:jet_plugin_sdk, __MODULE__))
  end

  defimpl JetPluginSDK.JetClient.Protocol do
    alias JetPluginSDK.GraphQLClient
    alias JetPluginSDK.Tenant
    alias JetPluginSDK.Tenant.Capability
    alias JetPluginSDK.Tenant.Config

    @instances_query """
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
    @spec list_instances(client :: @for.t()) ::
            {:ok, [Tenant.t()]}
            | {:error, Req.Response.t() | GraphQLClient.error()}
    def list_instances(client) do
      with {:ok, response} <- query(@instances_query, client),
           {:ok, instances} <- fetch_data(response, ["data", "instances"]) do
        {:ok, build_instances(instances)}
      end
    end

    defp fetch_data(response, path) do
      if Map.has_key?(response.body, "errors") do
        {:error, response}
      else
        {:ok, get_in(response.body, path)}
      end
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
          config: config |> Jason.decode!() |> Config.from_json(),
          capabilities: Enum.map(capabilities, &Capability.from_json/1)
        }
      end)
    end

    defp normalize_state("PENDING"), do: :pending
    defp normalize_state("INSTALLING"), do: :installing
    defp normalize_state("RUNNING"), do: :running
    defp normalize_state("UPDATING"), do: :updating
    defp normalize_state("UNINSTALLING"), do: :uninstalling
    defp normalize_state("ERROR_OCCURRED"), do: :error_occurred

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

    @spec send_event(client :: @for.t(), payload :: map()) ::
            :ok | {:error, GraphQLClient.error()}
    def send_event(client, payload) do
      variables = %{"payload" => payload}

      case query(@send_event_query, variables, client) do
        {:ok, %Req.Response{}} -> :ok
        otherwise -> otherwise
      end
    end

    defp query(doc, variables \\ %{}, client) do
      JetPluginSDK.GraphQLClient.query(client.endpoint, doc,
        headers: [{"x-jet-plugin-access-key", client.access_key}],
        variables: variables
      )
    end
  end
end
