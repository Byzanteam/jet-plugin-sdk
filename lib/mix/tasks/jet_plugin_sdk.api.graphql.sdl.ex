defmodule Mix.Tasks.JetPluginSdk.Api.Graphql.Sdl do
  @moduledoc false

  use Mix.Task

  alias Mix.Tasks.Absinthe.Schema.Sdl, as: SdlGenerator

  @impl Mix.Task
  def run(_argv) do
    define_schema()

    SdlGenerator.run([
      "--schema",
      Macro.to_string(__MODULE__.Schema),
      "generated/schema.graphql"
    ])
  end

  defp define_schema do
    Module.create(__MODULE__.Resolver, resolver_module(), __ENV__)
    Module.create(__MODULE__.Types, types_module(__MODULE__.Resolver), __ENV__)
    Module.create(__MODULE__.Schema, schema_module(__MODULE__.Types), __ENV__)
  end

  defp resolver_module do
    quote location: :keep do
      def initialize(_args, _resolution), do: nil
      def enable(_args, _resolution), do: nil
      def disable(_args, _resolution), do: nil
      def health_check(_args, _resolution), do: nil
    end
  end

  defp types_module(resolver_module) do
    quote location: :keep do
      use Absinthe.Schema.Notation

      import JetPluginSDK.API.GraphQL.Callbacks

      def_plugin_objects()

      object :jet_plugin_queries do
        def_plugin_callback_queries(unquote(resolver_module))
      end

      object :jet_plugin_mutations do
        def_plugin_callback_mutations(unquote(resolver_module))
      end
    end
  end

  defp schema_module(types_module) do
    quote location: :keep, generated: true do
      use Absinthe.Schema

      import_types unquote(types_module)

      query name: "JetPluginQuery" do
        import_fields :jet_plugin_queries
      end

      mutation name: "JetPluginMutation" do
        import_fields :jet_plugin_mutations
      end
    end
  end
end
