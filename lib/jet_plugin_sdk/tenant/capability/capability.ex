defmodule JetPluginSDK.Tenant.Capability do
  @moduledoc """
  The capabilities that Jet provides to plugins.
  """

  alias JetPluginSDK.Tenant.Capability.Database

  @type t() :: Database.t()
  @typep json() :: %{required(String.t()) => term()}
  @typep graphql_args() :: %{required(:__typename) => atom(), required(atom()) => term()}

  @spec from_json(json()) :: t()
  def from_json(%{"__typename" => "PluginInstanceCapabilityDatabase"} = map) do
    Database.from_json(map)
  end

  @spec from_graphql_args(graphql_args()) :: t()
  def from_graphql_args(%{__typename: :database} = map) do
    Database.from_graphql_args(map)
  end

  @callback from_json(json()) :: t()
  @callback from_graphql_args(graphql_args()) :: t()
end
