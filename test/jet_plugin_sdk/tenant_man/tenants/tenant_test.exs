defmodule JetPluginSDK.TenantMan.Tenants.TenantTest do
  use ExUnit.Case

  @moduletag :unit

  alias JetPluginSDK.Support.Tenant.Naive, as: NaiveTenant
  alias JetPluginSDK.Support.Tenant.ValidateConfig, as: ValidateConfigTenant

  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor
  alias JetPluginSDK.TenantMan.Tenants.Tenant

  setup do
    start_supervised!(JetPluginSDK.TenantMan.Supervisor)
    :ok
  end

  setup do
    %{
      tenant: %JetPluginSDK.Tenant{
        id: generate_tenant_id(),
        config: %{name: "bar"},
        state: :enabled
      }
    }
  end

  describe "fetch_tenant" do
    test "works", %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(tenant.id, NaiveTenant, tenant)

      assert {:ok, tenant} === Tenant.fetch_tenant(NaiveTenant, tenant.id)
    end

    test "fails", %{tenant: tenant} do
      assert :error === Tenant.fetch_tenant(NaiveTenant, "unknown")
      assert :error === Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end
  end

  describe "update_config" do
    setup %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(tenant.id, ValidateConfigTenant, tenant)

      :ok
    end

    test "works", %{tenant: tenant} do
      assert {:ok, %{name: "bar"}} ===
               Tenant.update_config(ValidateConfigTenant, tenant.id, %{name: "bar"})

      assert {:ok, %{config: %{name: "bar"}}} =
               Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end
  end

  defp generate_tenant_id do
    Base.encode64(:crypto.strong_rand_bytes(24))
  end
end
