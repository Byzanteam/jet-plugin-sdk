defmodule JetPluginSDK.TenantMan.Tenants.NaiveTenantTest do
  use JetPluginSDK.TenantCase, async: true

  describe "install" do
    test "works", ctx do
      :ok =
        @tenant_module.install(
          ctx.tenant.id,
          {ctx.tenant.config, ctx.tenant.capabilities}
        )

      assert match?(
               %JetPluginSDK.Tenant{config: %{name: "foo"}, state: :running},
               fetch_tenant!(ctx.tenant.id)
             )
    end

    test "return errors when the installation fails", ctx do
      assert {:error, :install_failed} =
               @tenant_module.install(
                 ctx.tenant.id,
                 {%{ctx.tenant.config | name: "error"}, ctx.tenant.capabilities}
               )

      assert_tenant_not_found(ctx.tenant.id)
    end

    test "returns error when the instance exists", ctx do
      :ok =
        @tenant_module.install(
          ctx.tenant.id,
          {ctx.tenant.config, ctx.tenant.capabilities}
        )

      assert {:error, :already_exists} =
               @tenant_module.install(
                 ctx.tenant.id,
                 {ctx.tenant.config, ctx.tenant.capabilities}
               )

      assert match?(
               %JetPluginSDK.Tenant{config: %{name: "foo"}, state: :running},
               fetch_tenant!(ctx.tenant.id)
             )

      assert %{active: 1, workers: 1} =
               DynamicSupervisor.count_children(Module.concat(@tenant_module, TenantsSupervisor))
    end
  end

  describe "update" do
    setup ctx do
      :ok =
        @tenant_module.install(
          ctx.tenant.id,
          {ctx.tenant.config, ctx.tenant.capabilities}
        )
    end

    test "works", ctx do
      :ok =
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
               fetch_tenant!(ctx.tenant.id)
             )
    end

    test "return errors when the update fails", ctx do
      assert {:error, :update_failed} =
               @tenant_module.update(
                 ctx.tenant.id,
                 {%{ctx.tenant.config | name: "error"},
                  [%Database{schema: "public", database_url: "postgres://localhost:5432/foo"}]}
               )

      assert match?(
               %JetPluginSDK.Tenant{
                 config: %{name: "foo"},
                 capabilities: [],
                 state: :error_occurred
               },
               fetch_tenant!(ctx.tenant.id)
             )
    end
  end

  describe "uninstall" do
    setup ctx do
      :ok =
        @tenant_module.install(
          ctx.tenant.id,
          {ctx.tenant.config, ctx.tenant.capabilities}
        )
    end

    test "works", ctx do
      :ok = @tenant_module.uninstall(ctx.tenant.id)

      assert_tenant_not_found(ctx.tenant.id)
    end

    test "return errors when the update fails", ctx do
      :ok = @tenant_module.update(ctx.tenant.id, {%{name: "uninstall"}, []})

      assert {:error, :uninstall_failed} = @tenant_module.uninstall(ctx.tenant.id)

      assert match?(
               %JetPluginSDK.Tenant{
                 config: %{name: "uninstall"},
                 capabilities: [],
                 state: :error_occurred
               },
               fetch_tenant!(ctx.tenant.id)
             )
    end
  end
end
