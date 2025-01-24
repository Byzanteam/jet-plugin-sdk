defmodule JetPluginSDK do
  @moduledoc """
  Jet plugin SDK for elixir.

  ## Tenant

  SDK 提供了一套 behaviour 抽象用来实现插件的生命周期功能，只需实现 behaviour 中
  定义的回调函数即可。

  ```elixir
  defmodule JetSamplePlugin.Tenant do
    use JetPluginSDK.TenantMan.Tenants.Tenant

    @impl JetPluginSDK.TenantMan.Tenants.Tenant
    def handle_install(_tenant) do
      {:ok, %{}}
    end

    @impl JetPluginSDK.TenantMan.Tenants.Tenant
    def handle_run({_tenant, tenant_state}) do
      {:noreply, tenant_state}
    end
  end
  ```

  ## JetClient

  插件运行过程中有时需要调用 Jet 的相关接口，这些接口的调用都通过 JetClient 发
  起。想要让 JetClient 正常工作，需要为 JetCLient 提供相应的配置：

  ```elixir
  config :jet_plugin_sdk, JetPluginSDK.JetClient,
    endpoint: "http://plugin.jet.local/graphql",
    access_key: "t/lnVHUw89Vgd+sW"
  ```

  ## Warmup

  应用启动时可以自动从 Jet 获取插件的实例，并启动相应的 tenants，通过以下配置完成：

  ```elixir
  config :jet_plugin_sdk, JetPluginSDK.TenantMan,
    warm_up: [tenant_module: JetSamplePlugin.Tenant]
  ```
  """

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
    signer = Joken.Signer.create("EdDSA", %{"pem" => fetch_key(key_provider)})

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
