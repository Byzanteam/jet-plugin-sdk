defmodule JetPluginSDK.API.CapabilityNormalizer do
  @moduledoc """
  Converts a map to a capability struct.
  """

  import JetExt.Absinthe.OneOf.Helpers

  alias Absinthe.Blueprint.Input
  alias JetPluginSDK.Tenant.Capability

  @spec run(data :: map(), Input.Object.t()) ::
          {JetPluginSDK.Tenant.Capability.t(), Input.Value.literals()}
  def run(data, input_object) do
    {key, value} = unwrap_data(data)

    {
      Capability.from_graphql_args(Map.put(value, :__typename, key)),
      unwrap_input_object(input_object)
    }
  end
end
