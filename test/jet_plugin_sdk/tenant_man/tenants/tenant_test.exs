defmodule JetPluginSDK.TenantMan.Tenants.TenantTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias JetPluginSDK.Support.Tenant.Async, as: AsyncTenant
  alias JetPluginSDK.Support.Tenant.GenServerLike, as: GenServerLikeTenant
  alias JetPluginSDK.Support.Tenant.Naive, as: NaiveTenant
  alias JetPluginSDK.Support.Tenant.ValidateConfig, as: ValidateConfigTenant

  alias JetPluginSDK.TenantMan.Storage
  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor
  alias JetPluginSDK.TenantMan.Tenants.Tenant

  setup :setup_tenant

  describe "init" do
    test "fetch config at startup", context do
      {:ok, _pid} = start_tenant(NaiveTenant, context)

      assert_receive {:tenant_config, %{name: "bar"}}
    end
  end

  describe "fetch_tenant" do
    test "works", %{tenant: tenant} = context do
      {:ok, pid} = start_tenant(NaiveTenant, context)

      NaiveTenant.ping(pid)

      assert {:ok, %{config: %{name: "bar"}}} = Tenant.fetch_tenant(NaiveTenant, tenant.id)
    end

    test "fails", %{tenant: tenant} do
      assert :error === Tenant.fetch_tenant(NaiveTenant, "unknown")
      assert :error === Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end
  end

  describe "works with custom fetch_tenant" do
    test "works", %{tenant: tenant} do
      tenant_id = tenant.id
      parent = self()

      fetch_instance = fn ^tenant_id ->
        send(parent, {:instance_fetched, tenant_id})
        {:ok, %{config: %{name: "bar"}}}
      end

      {:ok, _pid} = NaiveTenant.start(tenant, fetch_instance: fetch_instance)

      assert_receive {:instance_fetched, ^tenant_id}
    end
  end

  describe "update" do
    test "works", %{tenant: tenant} = context do
      {:ok, _pid} = start_tenant(ValidateConfigTenant, context)

      assert :ok = Tenant.install(ValidateConfigTenant, tenant.id)

      assert {:ok, %{config: %{name: "bar"}}} =
               Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)

      assert :ok = Tenant.update(ValidateConfigTenant, tenant.id, %{name: "baz"})

      assert {:ok, %{config: %{name: "baz"}}} =
               Tenant.fetch_tenant(ValidateConfigTenant, tenant.id)
    end

    test "works with async", %{tenant: tenant} = context do
      {:ok, _pid} = start_tenant(AsyncTenant, context)

      assert :ok = Tenant.install(AsyncTenant, tenant.id)

      assert :async = Tenant.update(AsyncTenant, tenant.id, %{name: "bar"})
      assert {:ok, %{config: %{name: "bar"}}} = Tenant.fetch_tenant(AsyncTenant, tenant.id)
    end
  end

  describe "terminate" do
    test "works", %{tenant: tenant} = context do
      {:ok, pid} = start_tenant(NaiveTenant, context)

      NaiveTenant.ping(pid)

      assert {:ok, _tenant} = Storage.fetch({NaiveTenant, tenant.id})

      GenServer.stop(pid)

      # 等待 Storage 处理完 tenant 退出的消息
      Storage.insert(:key, :tenant)

      assert :error = Storage.fetch({NaiveTenant, tenant.id})
    end
  end

  describe "support gen_server callbacks" do
    test "works with handle_call", context do
      {:ok, pid} = start_tenant(GenServerLikeTenant, context)

      assert :pong === GenServer.call(pid, :ping)
    end
  end

  defp setup_tenant(_ctx) do
    id = JetPluginSDK.Tenant.build_tenant_id(generate_id(), generate_id(), generate_id())

    recipient = self()

    fetch_instance = fn ^id ->
      config = %{name: "bar"}
      send(recipient, {:tenant_config, config})
      {:ok, %{capabilities: [], config: config}}
    end

    [
      tenant: %JetPluginSDK.Tenant{id: id, config: %{name: "foo"}, state: :running},
      start_tenant_opts: [
        fetch_instance: fetch_instance
      ]
    ]
  end

  defp start_tenant(tenant_module, %{tenant: tenant, start_tenant_opts: opts}) do
    TenantsSupervisor.start_tenant(tenant_module, tenant, opts)
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(12))
  end
end
