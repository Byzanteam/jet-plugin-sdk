defmodule JetPluginSDK.TenantMan.Tenants.SupervisorTest do
  use ExUnit.Case

  @moduletag :unit

  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor

  setup do
    %{
      tenant: %JetPluginSDK.Tenant{
        id: generate_tenant_id(),
        config: %{foo: "bar"},
        state: :enabled
      }
    }
  end

  describe "start_tenant" do
    test "works", %{tenant: tenant} do
      assert {:ok, pid} =
               TenantsSupervisor.start_tenant(
                 tenant.id,
                 JetPluginSDK.Support.Tenant.Naive,
                 tenant
               )

      assert Process.alive?(pid)
    end

    test "fails when tenant already exists", %{tenant: tenant} do
      tenant_id = tenant.id

      assert {:ok, pid} =
               TenantsSupervisor.start_tenant(
                 tenant_id,
                 JetPluginSDK.Support.Tenant.Naive,
                 tenant
               )

      assert {:error, {:already_started, ^pid}} =
               TenantsSupervisor.start_tenant(
                 tenant_id,
                 JetPluginSDK.Support.Tenant.Naive,
                 tenant
               )

      assert Process.alive?(pid)
    end

    test "fails when `init` returns error", %{tenant: invalid_tenant} do
      valid_tenant = %JetPluginSDK.Tenant{
        id: generate_tenant_id(),
        config: %{name: "foobar"},
        state: :enabled
      }

      assert {:ok, pid} =
               TenantsSupervisor.start_tenant(
                 valid_tenant.id,
                 JetPluginSDK.Support.Tenant.ValidateConfig,
                 valid_tenant
               )

      assert {:error, {:invalid_config, [name: {"is invalid", validation: :required}]}} =
               TenantsSupervisor.start_tenant(
                 invalid_tenant.id,
                 JetPluginSDK.Support.Tenant.ValidateConfig,
                 invalid_tenant
               )

      assert Process.alive?(pid)
    end
  end

  defp generate_tenant_id do
    Base.encode64(:crypto.strong_rand_bytes(24))
  end
end
