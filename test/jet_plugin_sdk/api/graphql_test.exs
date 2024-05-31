defmodule JetPluginSDK.API.GraphQLTest do
  use ExUnit.Case, async: true

  defmodule Schema do
    use JetPluginSDK.API.GraphQL

    # define input_object for plugin_config
    plugin_config do
      field :foo, :string
    end

    @impl JetPluginSDK.API.GraphQL
    def initialize(_args, _resolution) do
      # implement initialize here
    end

    @impl JetPluginSDK.API.GraphQL
    def install(args, _resolution) do
      {:ok, %{message: inspect(args.capabilities), __callback_resp_type__: :ok}}
    end

    @impl JetPluginSDK.API.GraphQL
    def update(args, _resolution) do
      {:ok, %{message: inspect(args.capabilities), __callback_resp_type__: :ok}}
    end

    @impl JetPluginSDK.API.GraphQL
    def uninstall(_args, _resolution) do
      # implement uninstall here
    end

    @impl JetPluginSDK.API.GraphQL
    def health_check(_args, _resolution) do
      # implement health check here
    end
  end

  test "converts capabilities to their cooresponding structs" do
    doc = """
    mutation {
      jetPluginInstall(
        projectId: "1",
        envId: "2",
        instanceId: "3",
        config: {foo: "bar"},
        capabilities: [
          {
            database: {
              schema: "public",
              databaseUrl: "postgres://localhost:5432"
            }
          }
        ]
      ) {
        message
      }

      jetPluginUpdate(
        projectId: "1",
        envId: "2",
        instanceId: "3",
        config: {foo: "bar"},
        capabilities: [
          {
            database: {
              schema: "public",
              databaseUrl: "postgres://localhost:5432"
            }
          }
        ]
      ) {
        message
      }
    }
    """

    assert {:ok, %{data: data}} = Absinthe.run(doc, Schema)

    capabilities = [
      %JetPluginSDK.Tenant.Capability.Database{
        schema: "public",
        database_url: "postgres://localhost:5432"
      }
    ]

    assert get_in(data, ["jetPluginInstall", "message"]) =~ inspect(capabilities)
    assert get_in(data, ["jetPluginUpdate", "message"]) =~ inspect(capabilities)
  end

  defmodule MockTenant do
    @moduledoc false

    @spec install(
            JetPluginSDK.Tenant.id(),
            {JetPluginSDK.Tenant.config(), JetPluginSDK.Tenant.capabilities()}
          ) :: :ok | :async | {:error, term()}
    def install(_tenant_id, {_config, _capabilities}) do
      :ok
    end

    @spec update(
            JetPluginSDK.Tenant.id(),
            {JetPluginSDK.Tenant.config(), JetPluginSDK.Tenant.capabilities()}
          ) :: :ok | :async | {:error, term()}
    def update(_tenant_id, {_config, _capabilities}) do
      :ok
    end

    @spec uninstall(JetPluginSDK.Tenant.id()) :: :ok | :async | {:error, term()}
    def uninstall(_tenant_id) do
      :ok
    end
  end

  defmodule WithTenantSchema do
    use JetPluginSDK.API.GraphQL, tenant_module: MockTenant

    # define input_object for plugin_config
    plugin_config do
      field :foo, :string
    end

    @impl JetPluginSDK.API.GraphQL
    def initialize(_args, _resolution) do
      # implement initialize here
    end
  end

  test "generates default callbacks" do
    doc = """
    mutation {
      jetPluginInstall(
        projectId: "1",
        envId: "2",
        instanceId: "3",
        config: {foo: "bar"},
        capabilities: [
          {
            database: {
              schema: "public",
              databaseUrl: "postgres://localhost:5432"
            }
          }
        ]
      ) {
        message
      }
    }
    """

    assert {:ok, %{data: data}} = Absinthe.run(doc, WithTenantSchema)

    assert get_in(data, ["jetPluginInstall", "message"]) =~ "success"
  end
end
