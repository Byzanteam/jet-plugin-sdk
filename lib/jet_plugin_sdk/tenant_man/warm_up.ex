defmodule JetPluginSDK.TenantMan.WarmUp do
  @moduledoc false

  use Task, restart: :transient

  require Logger

  alias JetPluginSDK.JetClient

  @type start_opts() :: [tenant_module: module()]

  @spec start_link(start_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Task.start_link(__MODULE__, :run, [opts])
  end

  @spec run(start_opts()) :: :ok
  def run(opts) do
    Logger.debug("Start warming up tenants.")

    case fetch_instances() do
      {:ok, instances} ->
        tenant_module = Keyword.fetch!(opts, :tenant_module)
        start_tenants(instances, tenant_module)
        Logger.debug("Warm up tenants completed.")
        exit(:normal)

      otherwise ->
        exit(otherwise)
    end
  end

  defp fetch_instances do
    Logger.debug("Start requesting Jet to retrieve plugin instances.")

    case JetClient.fetch_instances() do
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
    |> Stream.reject(fn instance ->
      normalize_state(instance.state) === :pending
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

      JetPluginSDK.TenantMan.Tenants.Supervisor.start_tenant(tenant_module, tenant)
    end)
  end

  defp normalize_state("PENDING"), do: :pending
  defp normalize_state("INSTALLING"), do: :installing
  defp normalize_state("RUNNING"), do: :running
  defp normalize_state("UPDATING"), do: :updating
end
