defmodule JetPluginSDK.TenantMan.WarmUp do
  @moduledoc false

  use Task, restart: :transient

  require Logger

  alias JetPluginSDK.JetClient
  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor

  @type instance() :: %{tenant_id: JetPluginSDK.Tenant.id(), state: String.t()}
  @type list_instances() :: (() -> {:ok, [instance()]} | {:error, term()})

  @type start_opts() :: [
          tenant_module: module(),
          list_instances: list_instances(),
          start_tenant_opts: TenantsSupervisor.start_tenant_opts()
        ]

  @spec start_link(start_opts()) :: {:ok, pid()}
  def start_link(opts) do
    Task.start_link(__MODULE__, :run, [opts])
  end

  @spec run(start_opts()) :: :ok
  def run(opts) do
    {tenant_module, opts} = Keyword.pop!(opts, :tenant_module)
    {list_instances, opts} = Keyword.pop(opts, :list_instances, &JetClient.list_instances/0)

    Logger.debug("Start warming up tenants.")

    case list_instances(list_instances) do
      {:ok, instances} ->
        start_tenant_opts = Keyword.get(opts, :start_tenant_opts, [])
        start_tenants(instances, tenant_module, start_tenant_opts)
        Logger.debug("Warm up tenants completed.")
        exit(:normal)

      otherwise ->
        exit(otherwise)
    end
  end

  @spec list_instances(list_instances()) :: {:ok, [instance()]} | {:error, term()}
  defp list_instances(list_instances) when is_function(list_instances, 0) do
    Logger.debug("Start requesting Jet to retrieve plugin instances.")

    case list_instances.() do
      {:ok, instances} ->
        Logger.debug("Request completed, got #{inspect(length(instances))} instances.")
        {:ok, instances}

      otherwise ->
        Logger.debug("Could not fetch plugin instances. Reason: #{inspect(otherwise)}")
        otherwise
    end
  end

  @spec start_tenants([instance()], module(), TenantsSupervisor.start_tenant_opts()) :: :ok
  defp start_tenants(instances, tenant_module, start_tenant_opts) do
    instances
    |> Stream.reject(fn instance ->
      normalize_state(instance.state) === :pending
    end)
    |> Enum.each(fn instance ->
      tenant = %JetPluginSDK.Tenant{
        id: instance.tenant_id,
        state: normalize_state(instance.state)
      }

      TenantsSupervisor.start_tenant(tenant_module, tenant, start_tenant_opts)
    end)
  end

  defp normalize_state("PENDING"), do: :pending
  defp normalize_state("INSTALLING"), do: :installing
  defp normalize_state("RUNNING"), do: :running
  defp normalize_state("UPDATING"), do: :updating
end
