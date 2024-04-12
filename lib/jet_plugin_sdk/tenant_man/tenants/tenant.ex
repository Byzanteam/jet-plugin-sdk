defmodule JetPluginSDK.TenantMan.Tenants.Tenant do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  alias JetPluginSDK.TenantMan.Registry

  @typep tenant_id() :: JetPluginSDK.Tenant.id()
  @typep tenant_schema() :: JetPluginSDK.Tenant.t()
  @typep tenant_config() :: JetPluginSDK.Tenant.config()
  @typep tenant_state() :: term()
  @typep state() :: {tenant_schema(), tenant_state()}
  @typep async() :: {module(), atom(), args :: [term()]} | function()

  @typep extra() :: {:continue, continue_arg :: term()} | :hibernate | timeout()

  @callback handle_install(tenant_schema()) ::
              {:ok, tenant_state()}
              | {:async, async()}
              | {:error, term()}

  @callback handle_run(state()) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: term(), tenant_state()}

  @callback handle_update(config :: tenant_config(), state()) ::
              {:ok, tenant_state()}
              | {:ok, tenant_state(), extra()}
              | {:async, async()}
              | {:async, async(), extra()}
              | {:error, term()}

  @callback handle_uninstall(state()) ::
              {:ok, tenant_state()}
              | {:ok, tenant_state(), extra()}
              | {:async, async()}
              | {:async, async(), extra()}

  @callback handle_call(request :: term(), from :: GenServer.from(), state()) ::
              {:reply, reply, tenant_state()}
              | {:reply, reply, tenant_state(), extra()}
              | {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason, reply, tenant_state()}
              | {:stop, reason, tenant_state()}
            when reply: term(), reason: any()

  @callback handle_cast(request :: term(), state()) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: any(), tenant_state()}

  @callback handle_continue(continue_arg :: term(), state()) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: any(), tenant_state()}

  @callback handle_info(msg :: :timeout | term(), state()) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: any(), tenant_state()}

  @callback terminate(reason, state :: state()) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()} | term()

  @optional_callbacks handle_call: 3,
                      handle_cast: 2,
                      handle_continue: 2,
                      handle_info: 2,
                      handle_update: 2,
                      handle_uninstall: 1,
                      terminate: 2

  defmacro __using__(_opts) do
    quote location: :keep do
      alias JetPluginSDK.TenantMan.Registry
      alias JetPluginSDK.TenantMan.Tenants.Supervisor, as: Manager

      @typep start_link_opts() :: [
               name: Registry.name(),
               tenant: JetPluginSDK.Tenant.t()
             ]

      @behaviour unquote(__MODULE__)

      @spec start(tenant :: JetPluginSDK.Tenant.t()) :: DynamicSupervisor.on_start_child()
      def start(tenant) do
        Manager.start_tenant(__MODULE__, tenant)
      end

      @spec fetch(tenant_id :: JetPluginSDK.Tenant.id()) ::
              {:ok, JetPluginSDK.Tenant.t()} | :error
      def fetch(tenant_id) do
        unquote(__MODULE__).fetch_tenant(__MODULE__, tenant_id)
      end

      @spec install(teannt_id :: JetPluginSDK.Tenant.id()) :: :ok | :async | {:error, term()}
      def install(tenant_id) do
        unquote(__MODULE__).install(__MODULE__, tenant_id)
      end

      @spec update(tenant_id :: JetPluginSDK.Tenant.id(), config :: map()) ::
              :ok | :async | {:error, term()}
      def update(tenant_id, config) do
        unquote(__MODULE__).update(__MODULE__, tenant_id, config)
      end

      @spec uninstall(tenant_id :: JetPluginSDK.Tenant.id()) :: :ok | :async | {:error, term()}
      def uninstall(tenant_id) do
        unquote(__MODULE__).uninstall(__MODULE__, tenant_id)
      end

      @spec whereis(tenant_id :: JetPluginSDK.Tenant.id()) :: {:ok, pid()} | :error
      def whereis(tenant_id) do
        Registry.whereis(__MODULE__, tenant_id)
      end

      @spec start_link(start_link_opts()) :: GenServer.on_start()
      def start_link(args) do
        args
        |> Keyword.put(:tenant_module, __MODULE__)
        |> unquote(__MODULE__).start_link()
      end

      @spec child_spec(start_link_opts()) :: Supervisor.child_spec()
      def child_spec(opts) do
        %{
          id: {__MODULE__, opts},
          start: {__MODULE__, :start_link, [opts]},
          restart: :permanent,
          type: :worker
        }
      end

      @impl unquote(__MODULE__)
      def handle_update(_config, {_tenant, tenant_state}) do
        {:ok, tenant_state}
      end

      @impl unquote(__MODULE__)
      def handle_uninstall({_tenant, tenant_state}) do
        {:ok, tenant_state}
      end

      @impl unquote(__MODULE__)
      def terminate(_reason, _state) do
        :ok
      end

      defoverridable child_spec: 1, handle_update: 2, handle_uninstall: 1, terminate: 2
    end
  end

  @enforce_keys [:tenant_module, :tenant]
  defstruct [
    :tenant_module,
    :tenant,
    :tenant_state
  ]

  @type t() :: %__MODULE__{
          tenant_module: module(),
          tenant: tenant_schema(),
          tenant_state: tenant_state()
        }

  @type start_link_opts() :: [
          name: Registry.name(),
          tenant_module: module(),
          tenant: tenant_schema()
        ]

  @spec fetch_tenant(tenant_module :: module(), tenant_id :: tenant_id()) ::
          {:ok, tenant_schema()} | :error
  def fetch_tenant(tenant_module, tenant_id) do
    with {:ok, pid} <- Registry.whereis(tenant_module, tenant_id) do
      GenServer.call(pid, {:"$tenant_man", :fetch_tenant})
    end
  end

  @spec install(tenant_module :: module(), tenant_id :: tenant_id()) :: term()
  def install(tenant_module, tenant_id) do
    case Registry.whereis(tenant_module, tenant_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:"$tenant_man", :install})

      :error ->
        {:error, :tenant_not_found}
    end
  end

  @spec update(
          tenant_module :: module(),
          tenant_id :: tenant_id(),
          config :: tenant_config()
        ) :: term()
  def update(tenant_module, tenant_id, config) do
    case Registry.whereis(tenant_module, tenant_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:"$tenant_man", {:update, config}})

      :error ->
        {:error, :tenant_not_found}
    end
  end

  @spec uninstall(tenant_module :: module(), tenant_id :: tenant_id()) :: term()
  def uninstall(tenant_module, tenant_id) do
    case Registry.whereis(tenant_module, tenant_id) do
      {:ok, pid} -> GenServer.call(pid, {:"$tenant_man", :uninstall})
      :error -> {:error, :tenant_not_found}
    end
  end

  @spec start_link(start_link_opts()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop!(opts, :name)

    GenServer.start_link(__MODULE__, __struct__(opts), name: name)
  end

  @impl GenServer
  def init(%__MODULE__{} = state) do
    {:ok, state, {:continue, {:"$tenant_man", :fetch_config}}}
  end

  @impl GenServer
  def handle_call({:"$tenant_man", :fetch_tenant}, _from, %__MODULE__{} = state) do
    {:reply, {:ok, state.tenant}, state}
  end

  def handle_call({:"$tenant_man", :install}, _from, %__MODULE__{} = state) do
    Logger.debug(describe(state) <> " is installing.")

    case state.tenant_module.handle_install(state.tenant) do
      {:ok, tenant_state} ->
        {:reply, :ok, %{state | tenant_state: tenant_state},
         {:continue, {:"$tenant_man", :handle_run}}}

      {:async, async} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:install_async, async}}}}

      {:error, reason} ->
        {:stop, reason, {:error, reason}, state}
    end
  end

  def handle_call({:"$tenant_man", {:update, config}}, _from, %__MODULE__{} = state) do
    Logger.debug(describe(state) <> " is updating config with new config: #{inspect(config)}.")

    case state.tenant_module.handle_update(config, {state.tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        tenant = %{state.tenant | config: config}
        {:reply, :ok, %{state | tenant: tenant, tenant_state: tenant_state}}

      {:ok, tenant_state, extra} ->
        tenant = %{state.tenant | config: config}
        {:reply, :ok, %{state | tenant: tenant, tenant_state: tenant_state}, extra}

      {:async, async} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:update_async, async, config}}}}

      {:async, async, extra} ->
        {:reply, :async, state,
         {:continue, {:"$tenant_man", {:update_async, async, config, extra}}}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:"$tenant_man", :uninstall}, _from, %__MODULE__{} = state) do
    Logger.debug(describe(state) <> " is uninstalling.")

    case state.tenant_module.handle_uninstall({state.tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        {:reply, :ok, %{state | tenant_state: tenant_state}}

      {:ok, tenant_state, extra} ->
        {:reply, :ok, %{state | tenant_state: tenant_state}, extra}

      {:async, async} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:uninstall_async, async}}}}

      {:async, async, extra} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:uninstall_async, async, extra}}}}
    end
  end

  @impl GenServer
  def handle_call(request, from, %__MODULE__{} = state) do
    case state.tenant_module.handle_call(request, from, {state.tenant, state.tenant_state}) do
      reply when is_tuple(reply) and tuple_size(reply) in [3, 4] and elem(reply, 0) === :reply ->
        handle_reply_callback(reply, state)

      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, state)

      {:stop, reason, reply, tenant_state} ->
        Logger.debug(describe(state) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, reply, %{state | tenant_state: tenant_state}}

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(state) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  @impl GenServer
  def handle_cast(request, state) do
    wrap_reply(request, state.tenant_module, :handle_cast, state)
  end

  @impl GenServer
  def handle_info(msg, state) do
    wrap_reply(msg, state.tenant_module, :handle_info, state)
  end

  @impl GenServer
  def handle_continue({:"$tenant_man", :fetch_config}, %__MODULE__{} = state) do
    config = JetPluginSDK.JetClient.build_config()

    case JetPluginSDK.JetClient.fetch_tenant(state.tenant.id, config) do
      {:ok, tenant} ->
        {:noreply, %{state | tenant: Map.merge(state.tenant, tenant)}}

      {:error, reason} ->
        message = """
        #{describe(state)} stopped because it could not obtain its configuration.
        #{inspect(reason)}
        """

        Logger.debug(message)

        {:stop, {:shutdown, reason}, state}
    end
  end

  def handle_continue({:"$tenant_man", {:install_async, async}}, %__MODULE__{} = state) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_install_result()

        {:noreply, %{state | tenant_state: tenant_state},
         {:continue, {:"$tenant_man", :handle_run}}}

      {:error, _reason} ->
        report_install_result()
        {:noreply, state}
    end
  end

  def handle_continue({:"$tenant_man", :handle_run}, %__MODULE__{} = state) do
    case state.tenant_module.handle_run({state.tenant, state.tenant_state}) do
      {:noreply, tenant_state} ->
        {:noreply, %{state | tenant_state: tenant_state}}

      {:noreply, tenant_state, extra} ->
        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:stop, reason, tenant_state} ->
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  def handle_continue({:"$tenant_man", {:update_async, async, config}}, %__MODULE__{} = state) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result()
        tenant = %{state.tenant | config: config}
        {:noreply, %{state | tenant: tenant, tenant_state: tenant_state}}

      {:error, _reason} ->
        report_update_result()
        {:noreply, state}
    end
  end

  def handle_continue(
        {:"$tenant_man", {:update_async, async, config, extra}},
        %__MODULE__{} = state
      ) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result()
        tenant = %{state.tenant | config: config}
        {:noreply, %{state | tenant: tenant, tenant_state: tenant_state}, extra}

      {:error, _reason} ->
        report_update_result()
        {:noreply, state, extra}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async}}, %__MODULE__{} = state) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result()
        {:noreply, %{state | tenant_state: tenant_state}}

      {:error, _reason} ->
        report_uninstall_result()
        {:noreply, state}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async, extra}}, %__MODULE__{} = state) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result()
        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:error, _reason} ->
        report_uninstall_result()
        {:noreply, state, extra}
    end
  end

  def handle_continue(continue_arg, %__MODULE__{} = state) do
    wrap_reply(continue_arg, state.tenant_module, :handle_continue, state)
  end

  @impl GenServer
  def terminate(reason, %__MODULE__{} = state) do
    state.tenant_module.terminate(reason, {state.tenant, state.tenant_state})
  end

  defp run_async(async) when is_function(async, 0) do
    async.()
  end

  defp run_async({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
  end

  defp handle_reply_callback(reply, state) do
    case reply do
      {:reply, reply, tenant_state} ->
        {:reply, reply, %{state | tenant_state: tenant_state}}

      {:reply, reply, tenant_state, timeout_or_hibernate_or_continue} ->
        {:reply, reply, %{state | tenant_state: tenant_state}, timeout_or_hibernate_or_continue}
    end
  end

  defp handle_noreply_callback(reply, state) do
    case reply do
      {:noreply, tenant_state} ->
        {:noreply, %{state | tenant_state: tenant_state}}

      {:noreply, tenant_state, timeout_or_hibernate_or_continue} ->
        {:noreply, %{state | tenant_state: tenant_state}, timeout_or_hibernate_or_continue}
    end
  end

  defp wrap_reply(request, tenant_module, callback, state) do
    case apply(tenant_module, callback, [request, {state.tenant, state.tenant_state}]) do
      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, state)

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(state) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  defp report_install_result do
    # TODO: send install result through webhook
  end

  defp report_update_result do
    # TODO: send update result through webhook
  end

  defp report_uninstall_result do
    # TODO: send uninstall result through webhook
  end

  defp describe(%__MODULE__{} = state) do
    %{tenant: tenant, tenant_module: tenant_module} = state

    "#{inspect(tenant_module)}<#{tenant.id}>"
  end
end
