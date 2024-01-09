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

    # define input_object for enable_config
    enable_config do
      field :foo, :string
    end

    @impl JetPluginSDK.API.GraphQL
    def initialize(_args, _resolution) do
      # implement initialize here
    end

    @impl JetPluginSDK.API.GraphQL
    def enable(_args, _resolution) do
      # implement enable here
    end

    @impl JetPluginSDK.API.GraphQL
    def disable(_args, _resolution) do
      # implement disable here
    end

    @impl JetPluginSDK.API.GraphQL
    def health_check(_args, _resolution) do
      # implement health check here
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
  @type callback_response_error() :: %{
          optional(:message) => String.t(),
          optional(:extensions) => String.t(),
          __callback_resp_type__: :error,
          invalid_argument: String.t(),
          expected: String.t()
        }
  @type callback_response() :: callback_response_ok() | callback_response_error()

  @callback health_check(
              args :: %{},
              resolution()
            ) ::
              {:ok, callback_response()} | {:error, term()}
  @callback initialize(
              args :: %{},
              resolution()
            ) :: {:ok, manifest()} | {:error, term()}
  @callback enable(
              args :: %{
                project_id: String.t(),
                env_id: String.t(),
                instance_id: String.t(),
                config: map()
              },
              resolution()
            ) :: {:ok, callback_response()} | {:error, term()}
  @callback disable(
              args :: %{
                project_id: String.t(),
                env_id: String.t(),
                instance_id: String.t()
              },
              resolution()
            ) :: {:ok, callback_response()} | {:error, term()}

  defmacro __using__(opts) do
    behaviour =
      quote location: :keep do
        use Absinthe.Schema
        import JetPluginSDK.API.GraphQL, only: [enable_config: 1]

        # 这里必须放到 `use Absinthe.Schema` 后面，否则编译器不会保留 Absinthe.Scheme 的 behaviour
        @behaviour JetPluginSDK.API.GraphQL
      end

    [
      behaviour,
      types(),
      schema(opts)
    ]
  end

  @doc """
  Jet should call `jet_plugin_initialized` with enable config defined in this type.

  ```elixir
    enable_config do
      field :foo, :string
    end
  ```
  """
  defmacro enable_config(block) do
    quote location: :keep do
      input_object :jet_plugin_enable_config do
        unquote(block)
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
        field :jet_plugin_initialize, type: :jet_plugin_manifest do
          resolve &__MODULE__.initialize/2
        end

        @desc """
        Called when the plugin is enabled by a project.
        """
        field :jet_plugin_enable, type: :jet_plugin_callback_response do
          arg :project_id, non_null(:string)
          arg :env_id, non_null(:string)
          arg :instance_id, non_null(:string)
          arg :config, non_null(:jet_plugin_enable_config)

          resolve &__MODULE__.enable/2
        end

        @desc """
        Called when the plugin is disabled by a project.
        """
        field :jet_plugin_disable, type: :jet_plugin_callback_response do
          arg :project_id, non_null(:string)
          arg :env_id, non_null(:string)
          arg :instance_id, non_null(:string)

          resolve &__MODULE__.disable/2
        end

        unquote(mutation_fields)
      end
    end
  end
end
