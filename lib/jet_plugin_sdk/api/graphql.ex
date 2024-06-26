defmodule JetPluginSDK.API.GraphQL do
  @moduledoc """
  This module helps to define the GraphQL API schema for Jet plugins.

  ## define schema

  ```elixir
  defmodule MySchema do
    use JetPluginSDK.API.GraphQL,
      query_fields: [
        do:
          field :some_query, type: :string do
            resolve &__MODULE__.some_query/2
          end
      ],
      mutation_fields: [
        do:
          field :some_mutation, type: :string do
            resolve &__MODULE__.some_mutation/2
          end
      ]

    # define input_object for plugin_config
    plugin_config do
      field :foo, :string
    end

    @impl JetPluginSDK.API.GraphQL
    def initialize(_args, _resolution) do
      # implement initialize here
    end

    @impl JetPluginSDK.API.GraphQL
    def install(_args, _resolution) do
      # implement install here
    end

    @impl JetPluginSDK.API.GraphQL
    def update(_args, _resolution) do
    # implement update here
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
  ```

  ## generate callbacks via setting tenant_module

  ```elixir
  defmodule MySchema do
    use JetPluginSDK.API.GraphQL,
      tenant_module: MyApp.Tenant

    plugin_config do
      field :foo, :string
    end
  end
  ```
  """

  @typep resolution() :: Absinthe.Resolution.t()

  @type database_capability() :: %{
          __capability_type__: :database,
          enable: boolean()
        }
  @type capability() :: database_capability()
  @type manifest() :: %{
          optional(:api_endpoint) => String.t(),
          optional(:description) => String.t(),
          version: String.t(),
          capabilities: [capability()]
        }

  @type callback_response_ok() :: %{
          optional(:message) => String.t(),
          optional(:extensions) => String.t(),
          __callback_resp_type__: :ok
        }
  @type callback_response_async() :: %{
          optional(:message) => String.t(),
          optional(:extensions) => String.t(),
          __callback_resp_type__: :async
        }
  @type callback_response_error() :: %{
          optional(:message) => String.t(),
          optional(:extensions) => String.t(),
          __callback_resp_type__: :error,
          invalid_argument: String.t(),
          expected: String.t()
        }
  @type initialize_response() :: manifest() | callback_response_async()
  @type callback_response() ::
          callback_response_ok() | callback_response_async() | callback_response_error()

  @callback health_check(
              args :: %{},
              resolution()
            ) :: {:ok, callback_response()} | {:error, term()}

  @callback initialize(
              args :: %{},
              resolution()
            ) :: {:ok, initialize_response()} | {:error, term()}

  @callback install(
              args :: %{
                project_id: String.t(),
                env_id: String.t(),
                instance_id: String.t(),
                config: JetPluginSDK.Tenant.config(),
                capabilities: JetPluginSDK.Tenant.capabilities()
              },
              resolution()
            ) :: {:ok, callback_response()} | {:error, term()}

  @callback update(
              args :: %{
                project_id: String.t(),
                env_id: String.t(),
                instance_id: String.t(),
                config: JetPluginSDK.Tenant.config(),
                capabilities: JetPluginSDK.Tenant.capabilities()
              },
              resolution()
            ) :: {:ok, callback_response()} | {:error, term()}

  @callback uninstall(
              args :: %{
                project_id: String.t(),
                env_id: String.t(),
                instance_id: String.t()
              },
              resolution()
            ) :: {:ok, callback_response_ok() | callback_response_async()} | {:error, term()}

  defmacro __using__(opts \\ []) do
    tenant_module =
      opts
      |> Keyword.get(:tenant_module)
      |> Macro.expand(__CALLER__)

    behaviour =
      quote location: :keep do
        use Absinthe.Schema

        import JetPluginSDK.API.GraphQL, only: [plugin_config: 1]

        @prototype_schema JetExt.Absinthe.OneOf.SchemaProtoType
        # 这里必须放到 `use Absinthe.Schema` 后面，否则编译器不会保留 Absinthe.Scheme 的 behaviour
        @behaviour JetPluginSDK.API.GraphQL
        @defoverridable JetPluginSDK.API.GraphQL
      end

    [
      behaviour,
      behaviour_imp(tenant_module),
      types(),
      schema(opts)
    ]
  end

  @doc """
  Jet should call `jet_plugin_install` and `jet_plugin_update` with config defined in this type.

  ```elixir
    plugin_config do
      field :foo, :string
    end
  ```
  """
  defmacro plugin_config(block) do
    quote location: :keep do
      input_object :jet_plugin_config do
        unquote(block)
      end
    end
  end

  defp behaviour_imp(nil), do: nil

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp behaviour_imp(tenant_module) do
    quote location: :keep do
      @tenant_module unquote(tenant_module)

      @impl JetPluginSDK.API.GraphQL
      def install(args, _resolution) do
        tenant_id = JetPluginSDK.Tenant.build_tenant_id(args)

        case @tenant_module.install(tenant_id, {args.config, args.capabilities}) do
          :ok ->
            {:ok, %{__callback_resp_type__: :ok, message: "success"}}

          :async ->
            {:ok, %{__callback_resp_type__: :async}}

          {:error, error} ->
            {:error, inspect(error)}
        end
      end

      @impl JetPluginSDK.API.GraphQL
      def update(args, _resolution) do
        tenant_id = JetPluginSDK.Tenant.build_tenant_id(args)

        case @tenant_module.update(tenant_id, {args.config, args.capabilities}) do
          :ok ->
            {:ok, %{__callback_resp_type__: :ok, message: "success"}}

          :async ->
            {:ok, %{__callback_resp_type__: :async}}

          {:error, error} ->
            {:error, inspect(error)}
        end
      end

      @impl JetPluginSDK.API.GraphQL
      def uninstall(args, _resolution) do
        tenant_id = JetPluginSDK.Tenant.build_tenant_id(args)

        case @tenant_module.uninstall(tenant_id) do
          :ok ->
            {:ok, %{__callback_resp_type__: :ok, message: "success"}}

          :async ->
            {:ok, %{__callback_resp_type__: :async}}

          {:error, error} ->
            {:error, inspect(error)}
        end
      end

      @impl JetPluginSDK.API.GraphQL
      def health_check(_args, _resolution) do
        {:ok, %{__callback_resp_type__: :ok, message: "success"}}
      end
    end
  end

  defp types do
    quote location: :keep do
      object :jet_plugin_manifest do
        field :api_endpoint, :string
        field :description, :string
        field :version, non_null(:string)
        field :capabilities, list_of(non_null(:jet_plugin_capability))
      end

      interface :jet_plugin_capability do
        field :enable, non_null(:boolean)
      end

      object :jet_plugin_capability_database do
        field :enable, non_null(:boolean)

        interface :jet_plugin_capability

        is_type_of fn
          %{__capability_type__: :database} -> true
          _otherwise -> false
        end
      end

      input_object :jet_plugin_capability_input do
        directive :one_of

        private(
          :input_modifier,
          :with,
          {JetPluginSDK.API.CapabilityNormalizer, :run, []}
        )

        field :database, :jet_plugin_capability_database_input
      end

      input_object :jet_plugin_capability_database_input do
        field :schema, non_null(:string)
        field :database_url, non_null(:string)
      end

      interface :jet_plugin_callback_response do
        field :message, :string

        @desc """
        Arbitrary serialized JSON data.
        """
        field :extensions, :string
      end

      object :jet_plugin_callback_response_ok do
        field :message, :string
        field :extensions, :string

        interface :jet_plugin_callback_response

        is_type_of fn
          %{__callback_resp_type__: :ok} -> true
          _otherwise -> false
        end
      end

      object :jet_plugin_callback_response_async do
        field :message, :string
        field :extensions, :string

        interface :jet_plugin_callback_response

        is_type_of fn
          %{__callback_resp_type__: :async} -> true
          _otherwise -> false
        end
      end

      @desc """
      Issued when an argument of unexpected format is received.
      For example, a field `email` of type `string` expected an email
      address is filled out with a malformed string like `"foobar"`.
      """
      object :jet_plugin_callback_response_argument_error do
        field :message, :string
        field :extensions, :string

        field :invalid_argument, non_null(:string)
        field :expected, non_null(:string)

        interface :jet_plugin_callback_response

        is_type_of fn
          %{__callback_resp_type__: :error} -> true
          _otherwise -> false
        end
      end

      union :jet_plugin_initialize_response do
        types [:jet_plugin_manifest, :jet_plugin_callback_response_async]

        resolve_type fn
          %{__callback_resp_type__: :async}, _ -> :jet_plugin_callback_response_async
          %{version: _version}, _ -> :jet_plugin_manifest
        end
      end

      union :jet_plugin_uninstall_response do
        types [:jet_plugin_callback_response_ok, :jet_plugin_callback_response_async]

        resolve_type fn
          %{__callback_resp_type__: :ok}, _ -> :jet_plugin_callback_response_ok
          %{__callback_resp_type__: :async}, _ -> :jet_plugin_callback_response_async
        end
      end
    end
  end

  defp schema(opts) do
    query_fields = Keyword.get(opts, :query_fields)
    mutation_fields = Keyword.get(opts, :mutation_fields)

    quote location: :keep do
      # https://github.com/absinthe-graphql/absinthe/blob/3c102f044138c3edc86c45a989bba6b7da5d9361/lib/absinthe/phase/schema/introspection.ex#L40C11-L40C12
      # use default name for introspection
      query do
        field :jet_plugin_health_check, type: :jet_plugin_callback_response do
          resolve &__MODULE__.health_check/2
        end

        unquote(query_fields)
      end

      mutation do
        @desc """
        Called when the plugin is discovered by Jet. The plugin should respond
        immediately with plugin info and calls Jet's `plugin_initialized` api
        to finish initialization.
        """
        field :jet_plugin_initialize, type: :jet_plugin_initialize_response do
          resolve &__MODULE__.initialize/2
        end

        @desc """
        Called when the plugin is installed by a project.
        """
        field :jet_plugin_install, type: :jet_plugin_callback_response do
          arg :project_id, non_null(:string)
          arg :env_id, non_null(:string)
          arg :instance_id, non_null(:string)
          arg :config, non_null(:jet_plugin_config)
          arg :capabilities, non_null(list_of(non_null(:jet_plugin_capability_input)))

          middleware JetExt.Absinthe.OneOf.Middleware.InputModifier

          resolve &__MODULE__.install/2
        end

        @desc """
        Called when the plugin is updated by a project.
        """
        field :jet_plugin_update, type: :jet_plugin_callback_response do
          arg :project_id, non_null(:string)
          arg :env_id, non_null(:string)
          arg :instance_id, non_null(:string)
          arg :config, non_null(:jet_plugin_config)
          arg :capabilities, non_null(list_of(non_null(:jet_plugin_capability_input)))

          middleware JetExt.Absinthe.OneOf.Middleware.InputModifier

          resolve &__MODULE__.update/2
        end

        @desc """
        Called when the plugin is uninstalled by a project.
        """
        field :jet_plugin_uninstall, type: :jet_plugin_uninstall_response do
          arg :project_id, non_null(:string)
          arg :env_id, non_null(:string)
          arg :instance_id, non_null(:string)

          resolve &__MODULE__.uninstall/2
        end

        unquote(mutation_fields)
      end
    end
  end
end
