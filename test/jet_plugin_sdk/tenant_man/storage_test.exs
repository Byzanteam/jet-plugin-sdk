defmodule JetPluginSDK.TenantMan.StorageTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  @states [:pending, :installing, :running, :updating, :uninstalling, :error_occurred]

  alias JetPluginSDK.Support.JetClient.StaticInstances, as: StaticInstancesClient
  alias JetPluginSDK.Support.Tenant.Warmup, as: WarmupTenant
  alias JetPluginSDK.TenantMan.Storage

  setup :build_instances

  setup ctx do
    start_supervised!({WarmupTenant, jet_client: StaticInstancesClient.new(ctx.instances)})

    :ok
  end

  describe "warm up" do
    setup _ctx do
      started_instances =
        WarmupTenant.Storage
        |> :sys.get_state()
        |> Map.get(:instances)
        |> Enum.map(fn {pid, {tenant_id, _ref}} -> {pid, tenant_id} end)

      [started_instances: started_instances]
    end

    test "works", ctx do
      warm_up_count =
        ctx.instances |> Enum.reject(&(&1.state in [:pending, :installing])) |> Enum.count()

      assert Enum.count(ctx.started_instances) === warm_up_count

      assert %{active: ^warm_up_count, workers: ^warm_up_count} =
               DynamicSupervisor.count_children(WarmupTenant.TenantsSupervisor)

      assert check_instance_states(ctx.started_instances, ctx.instances)
    end
  end

  describe "handle tenant down" do
    test "tenant will be deleted when an installing tenant is down" do
      tenant = build_instance(:installing)
      tenant_id = tenant.id
      {:ok, pid} = Storage.insert(WarmupTenant, tenant)

      :ok = GenServer.stop(pid)
      :sys.get_state(WarmupTenant.Storage)

      assert :error = Storage.fetch(WarmupTenant, tenant.id)
      refute_receive {:handle_run, ^tenant_id}
    end

    test "tenant will be restarted when an running tenant is down" do
      tenant = build_instance(:running)
      tenant_id = tenant.id
      {:ok, pid} = Storage.insert(WarmupTenant, tenant)

      assert_receive {:handle_run, ^tenant_id}
      :ok = GenServer.stop(pid)

      :sys.get_state(WarmupTenant.Storage)

      {:ok, restart_pid} = WarmupTenant.whereis(tenant.id)

      assert pid !== restart_pid
      assert ^tenant = WarmupTenant.fetch!(tenant.id)
      assert_receive {:handle_run, ^tenant_id}
    end

    test "tennant will not running when handle_run failed" do
      tenant = build_instance(:running)
      tenant = %{tenant | config: %{pid: self(), runnable: false}}
      tenant_id = tenant.id

      {:ok, pid} = Storage.insert(WarmupTenant, tenant)

      :sys.get_state(pid)

      assert tenant = WarmupTenant.fetch!(tenant.id)
      assert tenant.state === :error_occurred
      assert_received {:not_runnable, ^tenant_id}
    end

    test "tenant will be restarted when an error occurred tenant is down" do
      tenant = build_instance(:error_occurred)
      tenant_id = tenant.id
      {:ok, pid} = Storage.insert(WarmupTenant, tenant)

      :ok = GenServer.stop(pid)

      :sys.get_state(WarmupTenant.Storage)

      {:ok, restart_pid} = WarmupTenant.whereis(tenant.id)

      assert pid !== restart_pid
      assert ^tenant = WarmupTenant.fetch!(tenant.id)
      refute_receive {:handle_run, ^tenant_id}
    end

    test "tenant will be deleted when an uninstalled is down" do
      tenant = build_instance(:running)
      tenant_id = tenant.id
      {:ok, _pid} = Storage.insert(WarmupTenant, tenant)
      assert_receive {:handle_run, ^tenant_id}

      :ok = WarmupTenant.uninstall(tenant.id)
      :sys.get_state(WarmupTenant.Storage)

      assert :error = Storage.fetch(WarmupTenant, tenant.id)
    end
  end

  defp build_instances(_ctx) do
    [instances: Enum.map(@states, &build_instance/1)]
  end

  defp build_instance(state) do
    %JetPluginSDK.Tenant{
      id: JetPluginSDK.Tenant.build_tenant_id(generate_id(), generate_id(), generate_id()),
      config: %{pid: self(), runnable: true},
      capabilities: [],
      state: state
    }
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(12))
  end

  defp check_instance_states(started_instances, warm_up_instances) do
    started_instances
    |> Enum.map(fn {_pid, tenant_id} ->
      WarmupTenant.fetch!(tenant_id)
    end)
    |> Enum.all?(fn instance ->
      warm_up_instances
      |> Enum.find(&(&1.id === instance.id))
      |> check_instance_state(instance)
    end)
  end

  defp check_instance_state(warm_up_instance, started_instance) do
    convert_state(warm_up_instance.state) === started_instance.state
  end

  defp convert_state(:updating), do: :running
  defp convert_state(:uninstalling), do: :running
  defp convert_state(state), do: state
end
