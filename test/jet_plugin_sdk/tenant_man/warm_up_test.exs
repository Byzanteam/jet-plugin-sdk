defmodule JetPluginSDK.TenantMan.WarmUpTest do
  use ExUnit.Case
  use Mimic

  alias JetPluginSDK.TenantMan.WarmUp

  @moduletag :unit

  setup do
    stub(JetPluginSDK.JetClient, :fetch_instances, fn _config ->
      {:ok, Enum.map(1..6, fn _i -> build_instance() end)}
    end)

    :ok
  end

  test "works" do
    WarmUp.run(
      tenant_module: JetPluginSDK.Support.Tenant.Naive,
      jet_endpoint: "http://jet.dev",
      jet_access_key: "access_key"
    )
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
