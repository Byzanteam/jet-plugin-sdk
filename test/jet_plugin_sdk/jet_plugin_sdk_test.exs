defmodule JetPluginSDK.JetPluginSDKTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Mimic

  @token_header "x-jet-plugin-api-key"
  @opts [key_provider: __MODULE__]

  setup :setup_joken

  describe "fetch_tenant_info/2" do
    test "conn" do
      conn = put_req_header(%Plug.Conn{}, @token_header, "token")

      assert {:ok, info} = JetPluginSDK.fetch_tenant_info(conn, @opts)

      assert match?(
               %{
                 project_id: "project_id",
                 environment_id: "environment_id",
                 instance_id: "instance_id"
               },
               info
             )
    end

    test "args" do
      args = %{connect_info: %{x_headers: [{@token_header, "token"}]}}

      assert {:ok, info} = JetPluginSDK.fetch_tenant_info(args, @opts)

      assert match?(
               %{
                 project_id: "project_id",
                 environment_id: "environment_id",
                 instance_id: "instance_id"
               },
               info
             )
    end
  end

  def fetch_key!, do: "public key"

  defp setup_joken(_ctx) do
    stub(Joken.Signer, :verify, fn _token, _signer ->
      {:ok, %{"projId" => "project_id", "envId" => "environment_id", "instId" => "instance_id"}}
    end)

    :ok
  end
end
