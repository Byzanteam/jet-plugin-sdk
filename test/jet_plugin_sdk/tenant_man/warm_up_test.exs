defmodule JetPluginSDK.TenantMan.WarmUpTest do
  use ExUnit.Case, async: true

  alias JetPluginSDK.TenantMan.WarmUp

  @moduletag :unit

  test "works" do
    list_instances = fn -> {:ok, Enum.map(1..6, fn _i -> build_instance() end)} end

    pid =
      spawn(fn ->
        WarmUp.run(
          tenant_module: JetPluginSDK.Support.Tenant.Naive,
          list_instances: list_instances
        )
      end)

    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "failed" do
    list_instances = fn -> {:error, :reason} end

    pid =
      spawn(fn ->
        WarmUp.run(
          tenant_module: JetPluginSDK.Support.Tenant.Naive,
          list_instances: list_instances
        )
      end)

    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, {:error, :reason}}
  end

  defp build_instance do
    %{
      tenant_id: JetPluginSDK.Tenant.build_tenant_id(generate_id(), generate_id(), generate_id()),
      state: "RUNNING"
    }
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(24))
  end
end
