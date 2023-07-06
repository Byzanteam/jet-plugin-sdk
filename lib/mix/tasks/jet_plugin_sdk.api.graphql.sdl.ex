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
    Module.create(__MODULE__.Schema, module_ast(), __ENV__)
  end

  defp module_ast do
    quote location: :keep do
      use JetPluginSDK.API.GraphQL

      enable_config do
        field :value, :string
      end

      @impl JetPluginSDK.API.GraphQL
      def initialize(_args, _resolution), do: nil

      @impl JetPluginSDK.API.GraphQL
      def enable(_args, _resolution), do: nil

      @impl JetPluginSDK.API.GraphQL
      def disable(_args, _resolution), do: nil

      @impl JetPluginSDK.API.GraphQL
      def health_check(_args, _resolution), do: nil
    end
  end
end
