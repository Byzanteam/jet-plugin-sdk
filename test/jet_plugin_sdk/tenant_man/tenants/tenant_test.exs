defmodule JetPluginSDK.TenantMan.Tenants.TenantTest do
  use ExUnit.Case

  @moduletag :unit

  alias JetPluginSDK.Support.Tenant.Async, as: AsyncTenant
  alias JetPluginSDK.Support.Tenant.Naive, as: NaiveTenant
  alias JetPluginSDK.Support.Tenant.ValidateConfig, as: ValidateConfigTenant

  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor
  alias JetPluginSDK.TenantMan.Tenants.Tenant

  setup :setup_tenant

  describe "fetch_tenant" do
    test "works", %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(NaiveTenant, tenant)

      assert {:ok, tenant} === Tenant.fetch_tenant(NaiveTenant, tenant.id)
    end

    test "fails", %{tenant: tenant} do
      assert :error === Tenant.fetch_tenant(NaiveTenant, "unknown")
      assert :error === Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end
  end

  describe "update" do
    test "works", %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(ValidateConfigTenant, tenant)

      assert :ok = Tenant.install(ValidateConfigTenant, tenant.id)
      assert :ok = Tenant.update(ValidateConfigTenant, tenant.id, %{name: "bar"})

      assert {:ok, %{config: %{name: "bar"}}} =
               Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end

    test "works with async", %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(AsyncTenant, tenant)

      assert :ok = Tenant.install(AsyncTenant, tenant.id)

      assert :async = Tenant.update(AsyncTenant, tenant.id, %{name: "bar"})
      assert {:ok, %{config: %{name: "bar"}}} = Tenant.fetch_tenant(AsyncTenant, tenant.id)
    end
  end

  defp setup_tenant(_ctx) do
    id = Base.encode64(:crypto.strong_rand_bytes(24))

    [tenant: %JetPluginSDK.Tenant{id: id, config: %{name: "foo"}, state: :running}]
  end
end
