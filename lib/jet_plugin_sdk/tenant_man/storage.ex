defmodule JetPluginSDK.TenantMan.Storage do
  @moduledoc false

  use GenServer

  @typep key() :: {tenant_module :: module(), tenant_id :: JetPluginSDK.Tenant.id()}
  @typep tenant() :: JetPluginSDK.Tenant.t()
  @typep state() :: term()

  defmodule State do
    @moduledoc false

    @enforce_keys [:tenant, :tenant_module]
    defstruct [:tenant, :tenant_module, :tenant_state]

    @type t() :: %__MODULE__{
            tenant: JetPluginSDK.Tenant.t(),
            tenant_module: module(),
            tenant_state: term()
          }
  end

  @spec build_key(tenant_module :: module(), tenant :: tenant()) :: key()
  def build_key(tenant_module, tenant) do
    {tenant_module, tenant.id}
  end

  @spec fetch(key :: key()) :: {:ok, State.t()} | :error
  def fetch(key) do
    case :ets.lookup(__MODULE__, key) do
      [{{tenant_module, _tenant_id}, tenant, tenant_state}] ->
        {:ok, %State{tenant: tenant, tenant_module: tenant_module, tenant_state: tenant_state}}

      [] ->
        :error
    end
  end

  @spec insert(key :: key(), tenant :: JetPluginSDK.Tenant.t()) :: :ok | :error
  def insert(key, tenant) do
    GenServer.call(__MODULE__, {:insert, key, tenant})
  end

  def update(key, tenant, state) do
    GenServer.call(__MODULE__, {:update, key, tenant, state})
  end

  @spec update_state(key :: key(), state :: state()) :: :ok
  def update_state(key, state) do
    GenServer.call(__MODULE__, {:update_state, key, state})
  end

  def update_tenant(key, tenant) do
    GenServer.call(__MODULE__, {:update_tenant, key, tenant})
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
  def handle_call({:insert, key, tenant}, _from, table) do
    if :ets.insert_new(table, {key, tenant, nil}) do
      {:reply, :ok, table}
    else
      {:reply, :error, table}
    end
  end

  def handle_call({:update, key, tenant, state}, _from, table) do
    :ets.update_element(table, key, [{2, tenant}, {3, state}])
    {:reply, :ok, table}
  end

  def handle_call({:update_state, key, state}, _from, table) do
    :ets.update_element(table, key, {3, state})
    {:reply, :ok, table}
  end

  def handle_call({:update_tenant, key, tenant}, _from, table) do
    :ets.update_element(table, key, {2, tenant})
    {:reply, :ok, table}
  end
end
