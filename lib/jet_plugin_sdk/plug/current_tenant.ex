defmodule JetPluginSDK.Plug.CurrentTenant do
  @moduledoc false

  use Plug.Builder

  @tenant_key :jet_plugin_tenant

  @spec assign_tenant(conn :: conn, tenant :: map()) :: conn when conn: Plug.Conn.t()
  def assign_tenant(conn, tenant) do
    put_private(conn, @tenant_key, tenant)
  end

  @spec fetch_tenant(conn :: Plug.Conn.t()) :: {:ok, map()} | :error
  def fetch_tenant(conn) do
    Map.fetch(conn.private, @tenant_key)
  end

  @impl Plug
  def init(opts) do
    with(
      {:ok, key_provider} <- fetch_and_normalize_key_provider(opts),
      true <- ensure_compiled(key_provider)
    ) do
      [key_provider: key_provider]
    else
      _otherwise -> raise "Invalid key_provider"
    end
  end

  @impl Plug
  def call(conn, opts) do
    case JetPluginSDK.fetch_tenant_info(conn, opts) do
      {:ok, info} -> assign_tenant(conn, info)
      :error -> conn
    end
  end

  defp fetch_and_normalize_key_provider(opts) do
    case Keyword.fetch(opts, :key_provider) do
      {:ok, module} when is_atom(module) ->
        {:ok, {module, :fetch_key!}}

      {:ok, {module, fun} = key_provider} when is_atom(module) and is_atom(fun) ->
        {:ok, key_provider}

      _otherwise ->
        :error
    end
  end

  defp ensure_compiled({module, fun}) do
    match?({:module, _module}, Code.ensure_compiled(module)) and
      function_exported?(module, fun, 0)
  end
end
