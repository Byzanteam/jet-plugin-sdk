defmodule JetPluginSDK do
  @moduledoc false

  @token_header "x-jet-plugin-api-key"

  @typep info() :: %{
           project_id: binary(),
           environment_id: binary(),
           instance_id: binary()
         }

  @spec fetch_tenant_info(conn :: map(), opts :: keyword()) :: {:ok, info()} | :error
  def fetch_tenant_info(conn, opts) do
    with {:ok, token} <- extract_api_key(conn) do
      extract_tenant(token, opts)
    end
  end

  defp extract_api_key(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, @token_header) do
      [token] -> {:ok, token}
      _otherwise -> :error
    end
  end

  defp extract_api_key(%{connect_info: %{x_headers: headers}}) do
    case List.keyfind(headers, @token_header, 0) do
      nil -> :error
      {@token_header, token} -> {:ok, token}
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
