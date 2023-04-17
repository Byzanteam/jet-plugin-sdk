defmodule JetPluginSDK.API.GraphQL.Callbacks do
  @moduledoc false

  defmacro def_plugin_objects do
    common_objects()
  end

  defmacro def_plugin_callback_queries(resolver_module) do
    [
      health_check(resolver_module)
    ]
  end

  defmacro def_plugin_callback_mutations(resolver_module) do
    [
      initialize(resolver_module),
      enable(resolver_module),
      disable(resolver_module)
    ]
  end

  defp initialize(resolver_module) do
    quote location: :keep do
      @desc """
      Called when the plugin is discovered by Jet. The plugin should respond
      immediately with plugin info and calls Jet's `plugin_initialized` api
      to finish initialization.
      """
      field :jet_plugin_initialize, type: :jet_plugin_initialize_response do
        arg :jet_api_endpoint, non_null(:string)

        @desc """
        All calls to Jet's APIs require this access_key. So it should be
        persisted to local storage of the plugin.
        """
        arg :access_key, non_null(:string)

        resolve &unquote(resolver_module).initialize/2
      end
    end
  end

  defp enable(resolver_module) do
    quote location: :keep do
      @desc """
      Called when the plugin is enabled by a project.
      """
      field :jet_plugin_enable, type: :jet_plugin_void do
        arg :project_id, non_null(:string)
        arg :env, non_null(:jet_project_env)

        resolve &unquote(resolver_module).enable/2
      end
    end
  end

  defp disable(resolver_module) do
    quote location: :keep do
      @desc """
      Called when the plugin is disabled by a project.
      """
      field :jet_plugin_disable, type: :jet_plugin_void do
        arg :project_id, non_null(:string)
        arg :env, non_null(:jet_project_env)

        resolve &unquote(resolver_module).disable/2
      end
    end
  end

  defp health_check(resolver_module) do
    quote location: :keep do
      field :jet_plugin_health_check, type: :jet_plugin_void do
        resolve &unquote(resolver_module).health_check/2
      end
    end
  end

  defp common_objects do
    quote location: :keep do
      enum :jet_project_env do
        value :development
        value :production
      end

      enum :jet_plugin_void do
        value :void
      end

      object :jet_plugin_info do
        field :description, :string
        field :version, non_null(:string)
      end

      object :jet_plugin_initialize_response do
        field :info, non_null(:jet_plugin_info)
      end
    end
  end
end
