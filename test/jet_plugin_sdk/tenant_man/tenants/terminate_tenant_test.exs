defmodule JetPluginSDK.TenantMan.Tenants.TerminateTenantTest do
  use JetPluginSDK.TenantCase,
    tenant_module: JetPluginSDK.Support.Tenant.Terminate,
    async: true

  describe "terminate" do
    setup ctx do
      :ok =
        @tenant_module.install(
          ctx.tenant.id,
          {Map.put(ctx.tenant.config, :pid, self()), ctx.tenant.capabilities}
        )
    end

    test "terminate is called when GenServer stops", ctx do
      tenant_id = ctx.tenant.id
      {:ok, pid} = @tenant_module.whereis(tenant_id)

      GenServer.stop(pid)

      assert_receive({:tenant_terminated, ^tenant_id, :normal})
    end

    test "terminate is called when tenant uninstalled", ctx do
      tenant_id = ctx.tenant.id
      :ok = @tenant_module.uninstall(tenant_id)

      assert_receive({:tenant_terminated, ^tenant_id, :normal})
    end
  end
end
