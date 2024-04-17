defmodule JetPluginSDK.TenantMan.Storage do
  @moduledoc false

  use GenServer

  @typep key() :: {tenant_module :: module(), tenant_id :: JetPluginSDK.Tenant.id()}
  @typep tenant() :: JetPluginSDK.Tenant.t()

  @spec build_key(tenant_module :: module(), tenant :: tenant()) :: key()
  def build_key(tenant_module, tenant) do
    {tenant_module, tenant.id}
  end

  @spec fetch(key :: key()) :: {:ok, tenant()} | :error
  def fetch(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, _pid, tenant}] -> {:ok, tenant}
      [] -> :error
    end
  end

  @spec insert(key :: key(), tenant :: JetPluginSDK.Tenant.t()) :: :ok | :error
  def insert(key, tenant) do
    GenServer.call(__MODULE__, {:insert, key, tenant})
  end

  def update(key, tenant) do
    GenServer.call(__MODULE__, {:update, key, tenant})
  end

  @spec start_link(args :: keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    {:ok, :ets.new(__MODULE__, [:named_table, read_concurrency: true])}
  end

  @impl GenServer
  def handle_call({:insert, key, tenant}, {pid, _tag}, table) do
    if :ets.insert_new(table, {key, pid, tenant}) do
      Process.monitor(pid)
      {:reply, :ok, table}
    else
      {:reply, :error, table}
    end
  end

  def handle_call({:update, key, tenant}, _from, table) do
    :ets.update_element(table, key, {3, tenant})
    {:reply, :ok, table}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, table) do
    :ets.match_delete(table, {:"$1", pid, :"$2"})
    {:noreply, table}
  end
end
