defmodule JetPluginSDK.Plug.CurrentTenant do
  @moduledoc false

  use Plug.Builder

  @token_header "x-jet-plugin-api-key"

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

  @impl Plug
  def call(conn, opts) do
    with(
      {:ok, token} <- extract_api_key(conn),
      {:ok, tenant} <- extract_tenant(token, opts)
    ) do
      JetPluginSDK.Tenant.assign_tenant(conn, tenant)
    else
      _otherwise -> conn
    end
  end

  defp extract_api_key(conn) do
    case Plug.Conn.get_req_header(conn, @token_header) do
      [token] -> {:ok, token}
      _otherwise -> :error
    end
  end

  defp extract_tenant(token, key_provider: key_provider) do
    signer = Joken.Signer.create("RS256", %{"pem" => fetch_key(key_provider)})

    case Joken.Signer.verify(token, signer) do
      {:ok, %{"projId" => project_id, "envId" => environment_id, "instId" => instance_id}} ->
        {:ok, %{project_id: project_id, environment_id: environment_id, instance_id: instance_id}}

      _otherwise ->
        :error
    end
  end

  defp fetch_key(key_provider) when is_atom(key_provider) do
    key_provider.fetch_key!()
  end

  defp fetch_key({module, fun}) when is_atom(module) and is_atom(fun) do
    apply(module, fun, [])
  end
end
