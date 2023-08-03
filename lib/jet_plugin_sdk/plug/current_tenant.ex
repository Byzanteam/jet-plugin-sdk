defmodule JetPluginSDK.Plug.CurrentTenant do
  @moduledoc false

  @behaviour Plug

  @token_header "X-Jet-Plugin-API-Key"

  @impl Plug
  def init(opts) do
    with(
      {:ok, key_provider} <- Keyword.fetch(opts, :key_provider),
      {:module, _module} <- Code.ensure_compiled(key_provider)
    ) do
      [key_provider: key_provider]
    else
      _otherwise -> raise "Invalid key key_provider"
    end
  end

  @impl Plug
  def call(conn, opts) do
    with(
      {:ok, token} <- extract_api_key(conn),
      {:ok, tenant} <- extract_tenant(token, opts)
    ) do
      Plug.Conn.put_private(conn, :jet_plugin_tenant, tenant)
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
