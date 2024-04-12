defmodule JetPluginSDK.TenantMan.WarmUpTest do
  use ExUnit.Case
  use Mimic

  alias JetPluginSDK.TenantMan.WarmUp

  @moduletag :unit

  setup :set_mimic_global
  setup :verify_on_exit!

  test "works" do
    expect(JetPluginSDK.JetClient, :fetch_instances, fn ->
      {:ok, Enum.map(1..6, fn _i -> build_instance() end)}
    end)

    pid = spawn(fn -> WarmUp.run(tenant_module: JetPluginSDK.Support.Tenant.Naive) end)

    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "failed" do
    expect(JetPluginSDK.JetClient, :fetch_instances, fn -> {:error, :reason} end)

    pid = spawn(fn -> WarmUp.run(tenant_module: JetPluginSDK.Support.Tenant.Naive) end)

    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, {:error, :reason}}
  end

  defp build_instance do
    {proj_id, env_id, inst_id} = {generate_id(), generate_id(), generate_id()}

    %{
      tenant_id: JetPluginSDK.Tenant.build_tenant_id(proj_id, env_id, inst_id),
      project_id: proj_id,
      environment_id: env_id,
      id: inst_id,
      config: %{"foo" => generate_id()},
      capabilities: [],
      state: "RUNNING"
    }
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(24))
  end
end
