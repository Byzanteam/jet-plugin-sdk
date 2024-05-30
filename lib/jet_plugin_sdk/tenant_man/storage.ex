defmodule JetPluginSDK.TenantMan.Storage do
  @moduledoc """
  The source of truth for tenant data.
  """

  require Logger

  alias JetPluginSDK.Tenant
  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor

  use GenServer

  @enforce_keys [:jet_client, :table, :tenant_module]
  defstruct [:jet_client, :table, :tenant_module, instances: %{}]

  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()
  @typep tenant_id() :: JetPluginSDK.Tenant.id()
  @typep tenant() :: JetPluginSDK.Tenant.t()
  @typep state() :: %__MODULE__{
           jet_client: JetPluginSDK.JetClient.Protocol.t(),
           table: :ets.table(),
           tenant_module: tenant_module(),
           instances: %{pid() => {tenant_id(), reference()}}
         }

  @spec fetch!(tenant_module(), tenant_id()) :: tenant()
  def fetch!(tenant_module, tenant_id) do
    case fetch(tenant_module, tenant_id) do
      {:ok, tenant} -> tenant
      :error -> raise "The tenant with id(#{inspect(tenant_id)}) is not found"
    end
  end

  @spec fetch(tenant_module(), tenant_id()) :: {:ok, tenant()} | :error
  def fetch(tenant_module, tenant_id) do
    case :ets.lookup(storage_name(tenant_module), tenant_id) do
      [{^tenant_id, tenant}] -> {:ok, tenant}
      [] -> :error
    end
  end

  @spec insert(tenant_module(), tenant()) ::
          {:ok, pid()} | {:error, :already_exists}
  def insert(tenant_module, tenant) do
    GenServer.call(storage_name(tenant_module), {:insert, tenant})
  end

  @spec update!(tenant_module(), tenant()) :: :ok
  def update!(tenant_module, tenant) do
    GenServer.call(storage_name(tenant_module), {:update, tenant})
  end

  @spec start_link(args :: [tenant_module: tenant_module()]) ::
          GenServer.on_start()
  def start_link(args) do
    tenant_module = Keyword.fetch!(args, :tenant_module)

    GenServer.start_link(__MODULE__, args, name: storage_name(tenant_module))
  end

  defp storage_name(tenant_module), do: Module.concat(tenant_module, Storage)

  @impl GenServer
  def init(opts) do
    tenant_module = Keyword.fetch!(opts, :tenant_module)
    jet_client = Keyword.fetch!(opts, :jet_client)

    table = :ets.new(storage_name(tenant_module), [:named_table, read_concurrency: true])

    {
      :ok,
      __struct__(
        jet_client: jet_client,
        table: table,
        tenant_module: tenant_module
      ),
      {:continue, :warmup}
    }
  end

  @impl GenServer
  def handle_call({:insert, tenant}, _from, %__MODULE__{} = state) do
    case fetch(state.tenant_module, tenant.id) do
      {:ok, _tenant} ->
        {:reply, {:error, :already_exists}, state}

      :error ->
        {pid, state} = insert_tenant(tenant, state)

        {:reply, {:ok, pid}, state}
    end
  end

  def handle_call({:update, tenant}, _from, %__MODULE__{} = state) do
    :ets.update_element(state.table, tenant.id, {2, tenant})

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_continue(:warmup, %__MODULE__{} = state) do
    {:ok, instances} = JetPluginSDK.JetClient.Protocol.list_instances(state.jet_client)

    state =
      instances
      |> Stream.flat_map(fn
        %{state: state} when state in [:pending, :installing] ->
          []

        %{state: state} = tenant when state in [:updating, :uninstalling] ->
          [%{tenant | state: :running}]

        tenant ->
          [tenant]
      end)
      |> Enum.reduce(state, fn tenant, acc ->
        tenant
        |> insert_tenant(acc)
        |> elem(1)
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, pid, reason}, %__MODULE__{} = state) do
    {tenant_id, ^ref} = Map.fetch!(state.instances, pid)
    Process.demonitor(ref, [:flush])

    tenant = fetch!(state.tenant_module, tenant_id)

    state =
      handle_tenant_down(
        tenant,
        reason,
        %{state | instances: Map.delete(state.instances, pid)}
      )

    {:noreply, state}
  end

  defp handle_tenant_down(%Tenant{state: :installing} = tenant, _reason, %__MODULE__{} = state) do
    :ets.delete(state.table, tenant.id)

    state
  end

  defp handle_tenant_down(%Tenant{state: tenant_state} = tenant, reason, %__MODULE__{} = state)
       when tenant_state in [:running, :error_occurred] do
    Logger.debug(
      describe(tenant, state) <>
        " in #{inspect(tenant_state)} is down due to #{inspect(reason)}, and will be restarted"
    )

    {:ok, pid} = TenantsSupervisor.start_tenant(state.tenant_module, tenant)
    ref = Process.monitor(pid)

    %{state | instances: Map.put(state.instances, pid, {tenant.id, ref})}
  end

  defp handle_tenant_down(%Tenant{state: :uninstalled} = tenant, _reason, %__MODULE__{} = state) do
    :ets.delete(state.table, tenant.id)

    state
  end

  @spec insert_tenant(tenant(), state()) :: {pid(), state()}
  defp insert_tenant(tenant, %__MODULE__{} = state) do
    true = :ets.insert_new(state.table, {tenant.id, tenant})

    {:ok, pid} = TenantsSupervisor.start_tenant(state.tenant_module, tenant)
    ref = Process.monitor(pid)

    {
      pid,
      %{state | instances: Map.put(state.instances, pid, {tenant.id, ref})}
    }
  end

  defp describe(tenant, state) do
    "#{inspect(state.tenant_module)}<#{tenant.id}>"
  end
end
