defmodule JetPluginSDK.Tenant.Capability.Database do
  @moduledoc false

  @behaviour JetPluginSDK.Tenant.Capability

  @enforce_keys [:schema, :database_url]
  defstruct [:schema, :database_url]

  @type t() :: %__MODULE__{
          schema: String.t(),
          database_url: String.t()
        }

  @impl JetPluginSDK.Tenant.Capability
  def from_json(%{"databaseUrl" => database_url, "schema" => schema}) do
    %__MODULE__{database_url: database_url, schema: schema}
  end

  @impl JetPluginSDK.Tenant.Capability
  def from_graphql_args(%{schema: schema, database_url: database_url}) do
    %__MODULE__{schema: schema, database_url: database_url}
  end
end
