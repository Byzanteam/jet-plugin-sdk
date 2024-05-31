defmodule JetPluginSDK.Support.JetClient.EventCapture do
  @moduledoc """
  This client captures send_event function calls into messages
  and send them back to the test `pid`.
  """

  @enforce_keys [:pid]
  defstruct [:pid]

  @type t() :: %__MODULE__{pid: pid()}

  @spec new() :: t()
  def new, do: %__MODULE__{pid: self()}

  defimpl JetPluginSDK.JetClient.Protocol do
    @spec list_instances(client :: @for.t()) :: {:ok, [JetPluginSDK.Tenant.t()]}
    def list_instances(_client) do
      {:ok, []}
    end

    @spec send_event(client :: @for.t(), _payload :: map()) :: :ok
    def send_event(client, payload) do
      send(client.pid, {:send_event, payload})

      :ok
    end
  end
end
