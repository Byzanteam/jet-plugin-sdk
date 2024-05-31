defmodule JetPluginSDK.TenantMan.Tenants.AsyncTenantTest do
  use JetPluginSDK.TenantCase,
    tenant_module: JetPluginSDK.Support.Tenant.Async,
    jet_client: JetPluginSDK.Support.JetClient.EventCapture,
    async: true

  describe "install asynchronously" do
    test "works", ctx do
      :async = @tenant_module.install(ctx.tenant.id, {ctx.tenant.config, ctx.tenant.capabilities})

      assert match?(
               %JetPluginSDK.Tenant{config: %{name: "foo"}, state: :running},
               @tenant_module.fetch_tenant(ctx.tenant.id)
             )

      assert_receive_successful_message("install")
    end

    test "failed", ctx do
      :async =
        @tenant_module.install(
          ctx.tenant.id,
          {%{ctx.tenant.config | name: "error"}, ctx.tenant.capabilities}
        )

      assert_receive_failed_message("install", :install_failed)

      assert_tenant_not_found(ctx.tenant.id)
    end
  end

  describe "update asynchronously" do
    setup ctx do
      :async = @tenant_module.install(ctx.tenant.id, {ctx.tenant.config, ctx.tenant.capabilities})

      assert_receive_successful_message("install")

      :ok
    end

    test "works", ctx do
      :async =
        @tenant_module.update(
          ctx.tenant.id,
          {
            %{name: "bar"},
            [%Database{schema: "public", database_url: "postgres://localhost:5432/foo"}]
          }
        )

      assert match?(
               %JetPluginSDK.Tenant{
                 config: %{name: "bar"},
                 capabilities: [
                   %Database{
                     schema: "public",
                     database_url: "postgres://localhost:5432/foo"
                   }
                 ],
                 state: :running
               },
               @tenant_module.fetch_tenant(ctx.tenant.id)
             )

      assert_receive_successful_message("update")
    end

    test "failed", ctx do
      :async =
        @tenant_module.update(
          ctx.tenant.id,
          {%{ctx.tenant.config | name: "update"},
           [%Database{schema: "public", database_url: "postgres://localhost:5432/foo"}]}
        )

      assert match?(
               %JetPluginSDK.Tenant{
                 config: %{name: "foo"},
                 capabilities: [],
                 state: :error_occurred
               },
               @tenant_module.fetch_tenant(ctx.tenant.id)
             )

      assert_receive_failed_message("update", :update_failed)
    end
  end

  describe "uninstall asynchronously" do
    setup ctx do
      :async = @tenant_module.install(ctx.tenant.id, {ctx.tenant.config, ctx.tenant.capabilities})

      assert_receive_successful_message("install")

      :ok
    end

    test "works", ctx do
      {:ok, pid} = @tenant_module.whereis(ctx.tenant.id)
      ref = Process.monitor(pid)

      :async = @tenant_module.uninstall(ctx.tenant.id)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

      assert_receive_successful_message("uninstall")

      assert_tenant_not_found(ctx.tenant.id)
    end

    test "failed", ctx do
      :async =
        @tenant_module.update(
          ctx.tenant.id,
          {%{ctx.tenant.config | name: "uninstall"}, []}
        )

      assert_receive_successful_message("update")

      :async = @tenant_module.uninstall(ctx.tenant.id)

      assert match?(
               %JetPluginSDK.Tenant{
                 config: %{name: "uninstall"},
                 capabilities: [],
                 state: :error_occurred
               },
               @tenant_module.fetch_tenant(ctx.tenant.id)
             )

      assert_receive_failed_message("uninstall", :uninstall_failed)
    end
  end
end
