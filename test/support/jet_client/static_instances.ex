defmodule JetPluginSDK.Support.JetClient.StaticInstances do
  @moduledoc """
  This client returns a static list of instances, and
  transforms all events into a list of messages that are sent back to the test `pid`.
  """

  @enforce_keys [:instances, :pid]
  defstruct [:instances, :pid]

  @type t() :: %__MODULE__{
          instances: [JetPluginSDK.Tenant.t()],
          pid: pid()
        }

  @spec new(instances :: [JetPluginSDK.Tenant.t()]) :: t()
  def new(instances), do: %__MODULE__{instances: instances, pid: self()}

  defimpl JetPluginSDK.JetClient.Protocol do
    @spec list_instances(client :: @for.t()) :: {:ok, [JetPluginSDK.Tenant.t()]}
    def list_instances(client) do
      {:ok, client.instances}
    end

    @spec send_event(client :: @for.t(), _payload :: map()) :: :ok
    def send_event(client, payload) do
      send(client.pid, {:send_event, self(), payload})

      :ok
    end
  end
end
