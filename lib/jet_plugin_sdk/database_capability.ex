defmodule JetPluginSDK.DatabaseCapability do
  @moduledoc false

  @enforce_keys [:schema, :database_url]
  defstruct [:schema, :database_url]

  @type t() :: %__MODULE__{
          schema: String.t(),
          database_url: String.t()
        }

  @spec from_map(map()) :: t()
  def from_map(%{
        "__typename" => "PluginInstanceCapabilityDatabase",
        "databaseUrl" => database_url,
        "schema" => schema
      }) do
    %__MODULE__{database_url: database_url, schema: schema}
  end
end
