defmodule JetPluginSDK.JetClient.Blackhole do
  @moduledoc """
  This client returns empty instances and ignores all events.
  """

  defstruct []

  @type t() :: %__MODULE__{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  defimpl JetPluginSDK.JetClient.Protocol do
    @spec list_instances(client :: @for.t()) :: {:ok, [JetPluginSDK.Tenant.t()]}
    def list_instances(_client) do
      {:ok, []}
    end

    @spec send_event(client :: @for.t(), _payload :: map()) :: :ok
    def send_event(_client, _payload) do
      :ok
    end
  end
end
