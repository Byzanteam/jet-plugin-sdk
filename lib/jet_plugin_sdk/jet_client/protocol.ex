defprotocol JetPluginSDK.JetClient.Protocol do
  @moduledoc false

  alias JetPluginSDK.Tenant

  @typep reason() :: term()

  @spec list_instances(client :: t()) :: {:ok, [Tenant.t()]} | {:error, reason()}
  def list_instances(client)

  @spec send_event(client :: t(), payload :: map()) :: :ok | {:error, reason()}
  def send_event(client, payload)
end
