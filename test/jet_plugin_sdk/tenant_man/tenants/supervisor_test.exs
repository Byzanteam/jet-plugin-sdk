defmodule JetPluginSDK.TenantMan.Tenants.SupervisorTest do
  use ExUnit.Case

  @moduletag :unit

  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor

  setup :setup_tenant

  describe "start_tenant" do
    test "works", %{tenant: tenant} do
      assert {:ok, pid} =
               TenantsSupervisor.start_tenant(JetPluginSDK.Support.Tenant.Naive, tenant)

      assert Process.alive?(pid)
    end

    test "fails when tenant already exists", %{tenant: tenant} do
      assert {:ok, pid} =
               TenantsSupervisor.start_tenant(JetPluginSDK.Support.Tenant.Naive, tenant)

      assert {:error, {:already_started, ^pid}} =
               TenantsSupervisor.start_tenant(JetPluginSDK.Support.Tenant.Naive, tenant)

      assert Process.alive?(pid)
    end
  end

  defp setup_tenant(_ctx) do
    id = Base.encode64(:crypto.strong_rand_bytes(24))

    [tenant: %JetPluginSDK.Tenant{id: id, config: %{foo: "bar"}, state: :running}]
  end
end
