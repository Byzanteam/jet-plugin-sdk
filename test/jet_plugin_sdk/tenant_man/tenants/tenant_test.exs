defmodule JetPluginSDK.TenantMan.Tenants.TenantTest do
  use ExUnit.Case
  use Mimic

  @moduletag :unit

  alias JetPluginSDK.Support.Tenant.Async, as: AsyncTenant
  alias JetPluginSDK.Support.Tenant.GenServerLike, as: GenServerLikeTenant
  alias JetPluginSDK.Support.Tenant.Naive, as: NaiveTenant
  alias JetPluginSDK.Support.Tenant.ValidateConfig, as: ValidateConfigTenant

  alias JetPluginSDK.TenantMan.Storage
  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor
  alias JetPluginSDK.TenantMan.Tenants.Tenant

  setup :set_mimic_global
  setup :setup_tenant
  setup :setup_mimic

  describe "init" do
    test "fetch config at startup", %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(NaiveTenant, tenant)

      assert_receive {:tenant_config, %{name: "bar"}}
    end
  end

  describe "fetch_tenant" do
    test "works", %{tenant: tenant} do
      {:ok, pid} = TenantsSupervisor.start_tenant(NaiveTenant, tenant)

      NaiveTenant.ping(pid)

      assert {:ok, %{config: %{name: "bar"}}} = Tenant.fetch_tenant(NaiveTenant, tenant.id)
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

      assert {:ok, %{config: %{name: "bar"}}} =
               Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)

      assert :ok = Tenant.update(ValidateConfigTenant, tenant.id, %{name: "baz"})

      assert {:ok, %{config: %{name: "baz"}}} =
               Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end

    test "works with async", %{tenant: tenant} do
      {:ok, _pid} = TenantsSupervisor.start_tenant(AsyncTenant, tenant)

      assert :ok = Tenant.install(AsyncTenant, tenant.id)

      assert :async = Tenant.update(AsyncTenant, tenant.id, %{name: "bar"})
      assert {:ok, %{config: %{name: "bar"}}} = Tenant.fetch_tenant(AsyncTenant, tenant.id)
    end
  end

  describe "terminate" do
    test "works", %{tenant: tenant} do
      {:ok, pid} = TenantsSupervisor.start_tenant(NaiveTenant, tenant)

      NaiveTenant.ping(pid)

      assert {:ok, _tenant} = Storage.fetch({NaiveTenant, tenant.id})

      GenServer.stop(pid)

      assert :error = Storage.fetch({NaiveTenant, tenant.id})
    end
  end

  describe "support gen_server callbacks" do
    test "works with handle_call", %{tenant: tenant} do
      {:ok, pid} = TenantsSupervisor.start_tenant(GenServerLikeTenant, tenant)

      assert :pong === GenServer.call(pid, :ping)
    end
  end

  defp setup_tenant(_ctx) do
    id = JetPluginSDK.Tenant.build_tenant_id(generate_id(), generate_id(), generate_id())

    [tenant: %JetPluginSDK.Tenant{id: id, config: %{name: "foo"}, state: :running}]
  end

  defp setup_mimic(_ctx) do
    recipient = self()

    stub(JetPluginSDK.JetClient, :fetch_instance, fn _tenant_id ->
      config = %{name: "bar"}
      send(recipient, {:tenant_config, config})
      {:ok, %{capabilities: [], config: config}}
    end)

    :ok
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(12))
  end
end
