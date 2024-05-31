defmodule JetPluginSDK.TenantMan.Tenants.GenServerLikeTest do
  use JetPluginSDK.TenantCase,
    tenant_module: JetPluginSDK.Support.Tenant.GenServerLike,
    async: true

  describe "support gen_server callbacks" do
    setup ctx do
      :ok =
        @tenant_module.install(
          ctx.tenant.id,
          {ctx.tenant.config, ctx.tenant.capabilities}
        )
    end

    test "works with handle_call", ctx do
      {:ok, pid} = @tenant_module.whereis(ctx.tenant.id)

      assert :pong === GenServer.call(pid, :ping)
    end
  end
end
