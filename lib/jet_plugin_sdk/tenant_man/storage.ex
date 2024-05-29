defmodule JetPluginSDK.TenantMan.Storage do
  @moduledoc """
  The source of truth for tenant data.
  """

  require Logger

  alias JetPluginSDK.Tenant
  alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: TenantsSupervisor

  use GenServer

  @enforce_keys [:naming_fun, :table, :tenant_module]
  defstruct [:naming_fun, :table, :tenant_module, instances: %{}]

  @typep naming_fun() :: JetPluginSDK.TenantMan.naming_fun()
  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()
  @typep tenant_id() :: JetPluginSDK.Tenant.id()
  @typep tenant() :: JetPluginSDK.Tenant.t()
  @typep state() :: %__MODULE__{
           naming_fun: naming_fun(),
           table: :ets.table(),
           tenant_module: tenant_module(),
           instances: %{pid() => {tenant_id(), reference()}}
         }

  @spec fetch!(naming_fun(), tenant_id()) :: tenant()
  def fetch!(naming_fun, tenant_id) do
    case fetch(naming_fun, tenant_id) do
      {:ok, tenant} -> tenant
      :error -> raise "The tenant with id(#{inspect(tenant_id)}) is not found"
    end
  end

  @spec fetch(naming_fun(), tenant_id()) :: {:ok, tenant()} | :error
  def fetch(naming_fun, tenant_id) do
    case :ets.lookup(naming_fun.(:storage), tenant_id) do
      [{^tenant_id, tenant}] -> {:ok, tenant}
      [] -> :error
    end
  end

  @spec insert(naming_fun(), tenant()) ::
          {:ok, pid()} | {:error, :already_exists}
  def insert(naming_fun, tenant) do
    GenServer.call(naming_fun.(:storage), {:insert, tenant})
  end

  @spec update!(naming_fun(), tenant()) :: :ok
  def update!(naming_fun, tenant) do
    GenServer.call(naming_fun.(:storage), {:update, tenant})
  end

  @spec start_link(args :: [naming_fun: naming_fun(), tenant_module: tenant_module()]) ::
          GenServer.on_start()
  def start_link(args) do
    naming_fun = Keyword.fetch!(args, :naming_fun)

    GenServer.start_link(__MODULE__, args, name: naming_fun.(:storage))
  end

  @impl GenServer
  def init(opts) do
    naming_fun = Keyword.fetch!(opts, :naming_fun)
    tenant_module = Keyword.fetch!(opts, :tenant_module)

    table = :ets.new(naming_fun.(:storage), [:named_table, read_concurrency: true])

    {
      :ok,
      __struct__(naming_fun: naming_fun, table: table, tenant_module: tenant_module),
      {:continue, :warmup}
    }
  end

  @impl GenServer
  def handle_call({:insert, tenant}, _from, %__MODULE__{} = state) do
    case fetch(state.naming_fun, tenant.id) do
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
    {:ok, instances} = JetPluginSDK.JetClient.list_instances()

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

    tenant = fetch!(state.naming_fun, tenant_id)

    state =
      handle_tenant_down(
        tenant,
        reason,
        %{state | instances: Map.delete(state.instances, pid)}
      )

    {:noreply, state}
  end

  defp handle_tenant_down(%Tenant{state: :installing} = tenant, reason, %__MODULE__{} = state) do
    Logger.debug(describe(tenant, state) <> " installation failed: #{inspect(reason)}")

    :ets.delete(state.table, tenant.id)

    state
  end

  defp handle_tenant_down(%Tenant{state: tenant_state} = tenant, _reason, %__MODULE__{} = state)
       when tenant_state in [:running, :error_occurred] do
    Logger.debug(
      describe(tenant, state) <> " is down due to #{inspect(tenant_state)}, and will be restarted"
    )

    {:ok, pid} = TenantsSupervisor.start_tenant(state.naming_fun, tenant)
    ref = Process.monitor(pid)

    %{state | instances: Map.put(state.instances, pid, {tenant.id, ref})}
  end

  defp handle_tenant_down(%Tenant{state: :uninstalled} = tenant, _reason, %__MODULE__{} = state) do
    Logger.debug(describe(tenant, state) <> " uninstallation completed")

    :ets.delete(state.table, tenant.id)

    state
  end

  @spec insert_tenant(tenant(), state()) :: {pid(), state()}
  defp insert_tenant(tenant, %__MODULE__{} = state) do
    true = :ets.insert_new(state.table, {tenant.id, tenant})

    {:ok, pid} = TenantsSupervisor.start_tenant(state.naming_fun, tenant)
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
