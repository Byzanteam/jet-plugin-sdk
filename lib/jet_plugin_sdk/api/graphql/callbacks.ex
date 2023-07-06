defmodule JetPluginSDK.API.GraphQL.Callbacks do
  @moduledoc false

  defmacro def_plugin_objects do
    common_objects()
  end

  defmacro def_plugin_callback_queries(opts) do
    resolver = Keyword.fetch!(opts, :resolver)

    [
      health_check(resolver)
    ]
  end

  defmacro def_plugin_callback_mutations(opts) do
    resolver = Keyword.fetch!(opts, :resolver)

    if Keyword.get(opts, :def_enable, true) do
      [
        initialize(resolver),
        enable(resolver),
        disable(resolver)
      ]
    else
      [
        initialize(resolver),
        disable(resolver)
      ]
    end
  end

  defp initialize(resolver) do
    quote location: :keep do
      @desc """
      Called when the plugin is discovered by Jet. The plugin should respond
      immediately with plugin info and calls Jet's `plugin_initialized` api
      to finish initialization.
      """
      field :jet_plugin_initialize, type: :jet_plugin_manifest do
        arg :jet_api_endpoint, non_null(:string)

        @desc """
        All calls to Jet's APIs require this access_key. So it should be
        persisted to local storage of the plugin.
        """
        arg :access_key, non_null(:string)

        resolve &unquote(resolver).initialize/2
      end
    end
  end

  defp enable(resolver) do
    quote location: :keep do
      require unquote(__MODULE__)

      @desc """
      Called when the plugin is enabled by a project.
      """
      field :jet_plugin_enable, type: :jet_plugin_callback_response do
        unquote(__MODULE__).enable_arguments()

        resolve &unquote(resolver).enable/2
      end
    end
  end

  defmacro enable_arguments do
    quote location: :keep do
      arg :project_id, non_null(:string)
      arg :env_id, non_null(:string)
      arg :instance_id, non_null(:string)

      @desc """
      Serialized JSON data.
      """
      arg :config, :string
    end
  end

  defp disable(resolver) do
    quote location: :keep do
      @desc """
      Called when the plugin is disabled by a project.
      """
      field :jet_plugin_disable, type: :jet_plugin_callback_response do
        arg :project_id, non_null(:string)
        arg :env_id, non_null(:string)
        arg :instance_id, non_null(:string)

        resolve &unquote(resolver).disable/2
      end
    end
  end

  defp health_check(resolver) do
    quote location: :keep do
      field :jet_plugin_health_check, type: :jet_plugin_callback_response do
        resolve &unquote(resolver).health_check/2
      end
    end
  end

  defp common_objects do
    quote location: :keep do
      object :jet_plugin_manifest do
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
end
