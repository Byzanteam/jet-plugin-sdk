defmodule JetPluginSDK.TenantMan.WarmUpTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  @states [:pending, :installing, :running, :updating, :uninstalling, :error_occurred]

  alias JetPluginSDK.Support.JetClient.StaticInstances, as: StaticInstancesClient
  alias JetPluginSDK.Support.Tenant.Naive, as: NaiveTenant

  setup :build_instances

  setup ctx do
    start_supervised!({NaiveTenant, jet_client: StaticInstancesClient.new(ctx.instances)})

    :ok
  end

  describe "warm up" do
    test "works", ctx do
      warm_up_count =
        ctx.instances |> Enum.reject(&(&1.state in [:pending, :installing])) |> Enum.count()

      instance_pids =
        NaiveTenant.Storage
        |> :sys.get_state()
        |> Map.get(:instances)
        |> Map.keys()

      assert Enum.count(instance_pids) === warm_up_count

      assert %{active: ^warm_up_count, workers: ^warm_up_count} =
               DynamicSupervisor.count_children(NaiveTenant.TenantsSupervisor)

      Enum.each(instance_pids, fn pid ->
        GenServer.stop(pid)
      end)

      :sys.get_state(NaiveTenant.Storage)

      assert %{active: ^warm_up_count, workers: ^warm_up_count} =
               DynamicSupervisor.count_children(NaiveTenant.TenantsSupervisor)
    end
  end

  defp build_instances(_ctx) do
    [instances: Enum.map(@states, &build_instance/1)]
  end

  defp build_instance(state) do
    %JetPluginSDK.Tenant{
      id: JetPluginSDK.Tenant.build_tenant_id(generate_id(), generate_id(), generate_id()),
      config: %{name: "foo"},
      capabilities: [],
      state: state
    }
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(12))
  end
end
