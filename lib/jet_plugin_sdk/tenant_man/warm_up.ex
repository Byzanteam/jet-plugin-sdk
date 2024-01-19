defmodule JetPluginSDK.TenantMan.WarmUp do
  @moduledoc false

  use Task, restart: :transient

  require Logger

  alias JetPluginSDK.JetClient

  @type start_opts() :: [
          jet_endpoint: String.t() | URI.t(),
          jet_access_key: String.t(),
          tenant_module: module()
        ]

  @spec start_link(start_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Task.start_link(__MODULE__, :run, [opts])
  end

  @spec run(start_opts()) :: :ok
  def run(opts) do
    tenant_module = Keyword.fetch!(opts, :tenant_module)

    Logger.debug("Start warming up tenants.")

    with({:ok, instances} <- fetch_instances(opts)) do
      start_tenants(instances, tenant_module)
    end

    Logger.debug("Warm up tenants completed.")
  end

  defp fetch_instances(opts) do
    config = %{
      endpoint: Keyword.fetch!(opts, :jet_endpoint),
      access_key: Keyword.fetch!(opts, :jet_access_key)
    }

    Logger.debug("Start requesting Jet to retrieve plugin instances.")

    case JetClient.fetch_instances(config) do
      {:ok, instances} ->
        Logger.debug("Request completed, got #{inspect(length(instances))} instances.")
        {:ok, instances}

      otherwise ->
        Logger.debug("Could not fetch plugin instances. Reason: #{inspect(otherwise)}")
        otherwise
    end
  end

  defp start_tenants(instances, tenant_module) do
    instances
    |> Stream.filter(fn instance ->
      normalize_state(instance.state) === :enabled
    end)
    |> Enum.each(fn instance ->
      %{
        tenant_id: tenant_id,
        config: config,
        capabilities: capabilities,
        state: state
      } = instance

      tenant = %JetPluginSDK.Tenant{
        id: tenant_id,
        config: config,
        capabilities: capabilities,
        state: normalize_state(state)
      }

      JetPluginSDK.TenantMan.Tenants.Supervisor.start_tenant(
        tenant_id,
        tenant_module,
        tenant
      )
    end)
  end

  defp normalize_state("CREATED"), do: :created
  defp normalize_state("ENABLED"), do: :enabled
end
