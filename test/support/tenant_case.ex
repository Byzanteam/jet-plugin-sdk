defmodule JetPluginSDK.TenantCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias JetPluginSDK.TenantMan.Storage

  using opts do
    tenant_module = Keyword.get(opts, :tenant_module, JetPluginSDK.Support.Tenant.Naive)
    jet_client = Keyword.get(opts, :jet_client, JetPluginSDK.Support.JetClient.Blackhole)

    quote do
      @moduletag :unit

      @tenant_module unquote(tenant_module)

      alias JetPluginSDK.Tenant.Capability.Database

      import unquote(__MODULE__)

      setup do
        start_supervised!({unquote(tenant_module), jet_client: unquote(jet_client).new()})

        :ok
      end
    end
  end

  setup :setup_tenant

  def assert_receive_successful_message(event) do
    assert_receive({:send_event, payload})
    assert match?(%{^event => %{"success" => true}}, payload)
  end

  def assert_receive_failed_message(event, reason) do
    assert_receive({:send_event, payload})

    reason = inspect(reason)

    assert match?(
             %{
               ^event => %{
                 "success" => false,
                 "errors" => [%{"reason" => ^reason}]
               }
             },
             payload
           )
  end

  def assert_tenant_not_found(tenant_module, tenant_id) do
    assert_raise RuntimeError, ~r|not found|, fn ->
      # make sure that the storage has handled the DOWN message
      tenant_module |> Storage.storage_name() |> :sys.get_state()

      tenant_module.fetch!(tenant_id)
    end
  end

  defp setup_tenant(_ctx) do
    [
      tenant: %JetPluginSDK.Tenant{
        id: JetPluginSDK.Tenant.build_tenant_id(generate_id(), generate_id(), generate_id()),
        state: :installing,
        config: %{name: "foo"},
        capabilities: []
      }
    ]
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(12))
  end
end
