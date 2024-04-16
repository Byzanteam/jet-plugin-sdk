defmodule JetPluginSDK.TenantMan.Tenants.Tenant do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  alias JetPluginSDK.TenantMan.Registry
  alias JetPluginSDK.TenantMan.Storage

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

      defoverridable handle_update: 2, handle_uninstall: 1, terminate: 2
    end
  end

  @type start_link_opts() :: [
          name: Registry.name(),
          tenant_module: module(),
          tenant: tenant_schema()
        ]

  @spec fetch_tenant(tenant_module :: module(), tenant_id :: tenant_id()) ::
          {:ok, tenant_schema()} | :error
  def fetch_tenant(tenant_module, tenant_id) do
    with {:ok, state} <- Storage.fetch({tenant_module, tenant_id}) do
      {:ok, state.tenant}
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

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    tenant_module = Keyword.fetch!(opts, :tenant_module)
    tenant = Keyword.fetch!(opts, :tenant)
    key = Storage.build_key(tenant_module, tenant)

    case Storage.insert(key, tenant) do
      :ok ->
        {:ok, key, {:continue, {:"$tenant_man", :fetch_instance}}}

      :error ->
        Logger.error(describe(key) <> " already has a state")
        {:stop, :already_has_state}
    end
  end

  @impl GenServer
  def handle_call({:"$tenant_man", :install}, _from, key) do
    Logger.debug(describe(key) <> " is installing.")

    {:ok, state} = Storage.fetch(key)

    case state.tenant_module.handle_install(state.tenant) do
      {:ok, tenant_state} ->
        Storage.update_state(key, tenant_state)
        {:reply, :ok, key, {:continue, {:"$tenant_man", :handle_run}}}

      {:async, async} ->
        {:reply, :async, key, {:continue, {:"$tenant_man", {:install_async, async}}}}

      {:error, reason} ->
        {:stop, reason, {:error, reason}, key}
    end
  end

  def handle_call({:"$tenant_man", {:update, config}}, _from, key) do
    Logger.debug(describe(key) <> " is updating config with new config: #{inspect(config)}.")

    {:ok, state} = Storage.fetch(key)

    case state.tenant_module.handle_update(config, {state.tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        Storage.update(key, %{state.tenant | config: config}, tenant_state)
        {:reply, :ok, key}

      {:ok, tenant_state, extra} ->
        Storage.update(key, %{state.tenant | config: config}, tenant_state)
        {:reply, :ok, key, extra}

      {:async, async} ->
        {:reply, :async, key, {:continue, {:"$tenant_man", {:update_async, async, config}}}}

      {:async, async, extra} ->
        {:reply, :async, key,
         {:continue, {:"$tenant_man", {:update_async, async, config, extra}}}}

      {:error, reason} ->
        {:reply, {:error, reason}, key}
    end
  end

  def handle_call({:"$tenant_man", :uninstall}, _from, key) do
    Logger.debug(describe(key) <> " is uninstalling.")

    {:ok, state} = Storage.fetch(key)

    case state.tenant_module.handle_uninstall({state.tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        Storage.update_state(key, tenant_state)
        {:reply, :ok, key}

      {:ok, tenant_state, extra} ->
        Storage.update_state(key, tenant_state)
        {:reply, :ok, key, extra}

      {:async, async} ->
        {:reply, :async, key, {:continue, {:"$tenant_man", {:uninstall_async, async}}}}

      {:async, async, extra} ->
        {:reply, :async, key, {:continue, {:"$tenant_man", {:uninstall_async, async, extra}}}}
    end
  end

  @impl GenServer
  def handle_call(request, from, key) do
    {:ok, state} = Storage.fetch(key)

    case state.tenant_module.handle_call(request, from, {state.tenant, state.tenant_state}) do
      reply when is_tuple(reply) and tuple_size(reply) in [3, 4] and elem(reply, 0) === :reply ->
        handle_reply_callback(reply, key)

      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, key)

      {:stop, reason, reply, tenant_state} ->
        Logger.debug(describe(key) <> " is stopped with reason: #{inspect(reason)}.")
        Storage.update_state(key, tenant_state)
        {:stop, reason, reply, key}

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(key) <> " is stopped with reason: #{inspect(reason)}.")
        Storage.update_state(key, tenant_state)
        {:stop, reason, key}
    end
  end

  @impl GenServer
  def handle_cast(request, key) do
    wrap_reply(request, :handle_cast, key)
  end

  @impl GenServer
  def handle_info(msg, key) do
    wrap_reply(msg, :handle_info, key)
  end

  @impl GenServer
  def handle_continue({:"$tenant_man", :fetch_instance}, key) do
    {:ok, state} = Storage.fetch(key)

    case JetPluginSDK.JetClient.fetch_instance(state.tenant.id) do
      {:ok, instance} ->
        Storage.update_tenant(key, Map.merge(state.tenant, instance))
        {:noreply, key}

      {:error, reason} ->
        message = """
        #{describe(key)} stopped because it could not obtain its configuration.
        #{inspect(reason)}
        """

        Logger.debug(message)

        {:stop, {:shutdown, reason}, key}
    end
  end

  def handle_continue({:"$tenant_man", {:install_async, async}}, key) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_install_result()
        Storage.update_state(key, tenant_state)
        {:noreply, key, {:continue, {:"$tenant_man", :handle_run}}}

      {:error, _reason} ->
        report_install_result()
        {:noreply, key}
    end
  end

  def handle_continue({:"$tenant_man", :handle_run}, key) do
    {:ok, state} = Storage.fetch(key)

    case state.tenant_module.handle_run({state.tenant, state.tenant_state}) do
      {:noreply, tenant_state} ->
        Storage.update_state(key, tenant_state)
        {:noreply, key}

      {:noreply, tenant_state, extra} ->
        Storage.update_state(key, tenant_state)
        {:noreply, key, extra}

      {:stop, reason, tenant_state} ->
        Storage.update_state(key, tenant_state)
        {:stop, reason, key}
    end
  end

  def handle_continue({:"$tenant_man", {:update_async, async, config}}, key) do
    {:ok, state} = Storage.fetch(key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result()
        Storage.update(key, %{state.tenant | config: config}, tenant_state)
        {:noreply, key}

      {:error, _reason} ->
        report_update_result()
        {:noreply, key}
    end
  end

  def handle_continue({:"$tenant_man", {:update_async, async, config, extra}}, key) do
    {:ok, state} = Storage.fetch(key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result()
        Storage.update(key, %{state.tenant | config: config}, tenant_state)
        {:noreply, key, extra}

      {:error, _reason} ->
        report_update_result()
        {:noreply, key, extra}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async}}, key) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result()
        Storage.update_state(key, tenant_state)
        {:noreply, key}

      {:error, _reason} ->
        report_uninstall_result()
        {:noreply, key}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async, extra}}, key) do
    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result()
        Storage.update_state(key, tenant_state)
        {:noreply, key, extra}

      {:error, _reason} ->
        report_uninstall_result()
        {:noreply, key, extra}
    end
  end

  def handle_continue(continue_arg, key) do
    wrap_reply(continue_arg, :handle_continue, key)
  end

  @impl GenServer
  def terminate(reason, key) do
    {:ok, state} = Storage.fetch(key)
    state.tenant_module.terminate(reason, {state.tenant, state.tenant_state})
  end

  defp run_async(async) when is_function(async, 0) do
    async.()
  end

  defp run_async({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
  end

  defp handle_reply_callback(reply, key) do
    case reply do
      {:reply, reply, tenant_state} ->
        Storage.update_state(key, tenant_state)
        {:reply, reply, key}

      {:reply, reply, tenant_state, timeout_or_hibernate_or_continue} ->
        Storage.update_state(key, tenant_state)
        {:reply, reply, key, timeout_or_hibernate_or_continue}
    end
  end

  defp handle_noreply_callback(reply, key) do
    case reply do
      {:noreply, tenant_state} ->
        Storage.update_state(key, tenant_state)
        {:noreply, key}

      {:noreply, tenant_state, timeout_or_hibernate_or_continue} ->
        Storage.update_state(key, tenant_state)
        {:noreply, key, timeout_or_hibernate_or_continue}
    end
  end

  defp wrap_reply(request, callback, key) do
    {:ok, state} = Storage.fetch(key)

    case apply(state.tenant_module, callback, [request, {state.tenant, state.tenant_state}]) do
      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, key)

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(key) <> " is stopped with reason: #{inspect(reason)}.")
        Storage.update_state(key, tenant_state)
        {:stop, reason, key}
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

  defp describe({tenant_module, tenant_id}) do
    "#{inspect(tenant_module)}<#{tenant_id}>"
  end
end
