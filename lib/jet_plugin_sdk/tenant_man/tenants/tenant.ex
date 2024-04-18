defmodule JetPluginSDK.TenantMan.Tenants.Tenant do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  alias JetPluginSDK.TenantMan.Registry
  alias JetPluginSDK.TenantMan.Storage

  @enforce_keys [:key, :tenant_module]
  defstruct [:key, :tenant_module, :tenant_state]

  @typep tenant_id() :: JetPluginSDK.Tenant.id()
  @typep tenant_schema() :: JetPluginSDK.Tenant.t()
  @typep tenant_config() :: JetPluginSDK.Tenant.config()
  @typep tenent_capabilities() :: JetPluginSDK.Tenant.capabilities()
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

      @spec start(tenant :: JetPluginSDK.Tenant.t(), opts :: Manager.start_tenant_opts()) ::
              DynamicSupervisor.on_start_child()
      def start(tenant, opts \\ []) do
        Manager.start_tenant(__MODULE__, tenant, opts)
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

  @type instance() :: %{config: tenant_config(), capabilities: tenent_capabilities()}

  @type start_link_opts() :: [
          name: Registry.name(),
          tenant_module: module(),
          tenant: tenant_schema(),
          fetch_instance: (tenant_id() -> {:ok, instance()} | {:error, term()})
        ]

  @spec fetch_tenant(tenant_module :: module(), tenant_id :: tenant_id()) ::
          {:ok, tenant_schema()} | :error
  def fetch_tenant(tenant_module, tenant_id) do
    Storage.fetch({tenant_module, tenant_id})
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
    fetch_instance = Keyword.get(opts, :fetch_instance, &JetPluginSDK.JetClient.fetch_instance/1)

    state = %__MODULE__{
      key: Storage.build_key(tenant_module, tenant),
      tenant_module: tenant_module
    }

    {:ok, state, {:continue, {:"$tenant_man", {:fetch_instance, fetch_instance, tenant}}}}
  end

  @impl GenServer
  def handle_call({:"$tenant_man", :install}, _from, %__MODULE__{} = state) do
    Logger.debug(describe(state.key) <> " is installing.")

    {:ok, tenant} = Storage.fetch(state.key)

    case state.tenant_module.handle_install(tenant) do
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
    Logger.debug(
      describe(state.key) <> " is updating config with new config: #{inspect(config)}."
    )

    {:ok, tenant} = Storage.fetch(state.key)

    case state.tenant_module.handle_update(config, {tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        Storage.update(state.key, %{tenant | config: config})
        {:reply, :ok, %{state | tenant_state: tenant_state}}

      {:ok, tenant_state, extra} ->
        Storage.update(state.key, %{tenant | config: config})
        {:reply, :ok, %{state | tenant_state: tenant_state}, extra}

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
    Logger.debug(describe(state.key) <> " is uninstalling.")

    {:ok, tenant} = Storage.fetch(state.key)

    case state.tenant_module.handle_uninstall({tenant, state.tenant_state}) do
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
    {:ok, tenant} = Storage.fetch(state.key)

    case state.tenant_module.handle_call(request, from, {tenant, state.tenant_state}) do
      reply when is_tuple(reply) and tuple_size(reply) in [3, 4] and elem(reply, 0) === :reply ->
        handle_reply_callback(reply, state)

      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, state)

      {:stop, reason, reply, tenant_state} ->
        Logger.debug(describe(state.key) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, reply, %{state | tenant_state: tenant_state}}

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(state.key) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  @impl GenServer
  def handle_cast(request, %__MODULE__{} = state) do
    wrap_reply(request, :handle_cast, state)
  end

  @impl GenServer
  def handle_info(msg, %__MODULE__{} = state) do
    wrap_reply(msg, :handle_info, state)
  end

  @impl GenServer
  def handle_continue(
        {:"$tenant_man", {:fetch_instance, fetch_instance, tenant}},
        %__MODULE__{} = state
      )
      when is_function(fetch_instance, 1) do
    with {:ok, instance} <- fetch_instance.(tenant.id),
         :ok <- Storage.insert(state.key, struct(tenant, instance)) do
      {:noreply, state}
    else
      {:error, reason} ->
        message = """
        #{describe(state.key)} stopped because it could not obtain its configuration.
        #{inspect(reason)}
        """

        Logger.debug(message)

        {:stop, {:shutdown, reason}, state}

      :error ->
        Logger.debug(describe(state.key) <> " already has a state")

        {:stop, :already_has_state}
    end
  end

  def handle_continue({:"$tenant_man", {:install_async, async}}, %__MODULE__{} = state) do
    {:ok, tenant} = Storage.fetch(state.key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_install_result(tenant.id)

        {:noreply, %{state | tenant_state: tenant_state},
         {:continue, {:"$tenant_man", :handle_run}}}

      {:error, reason} ->
        report_install_result(tenant.id, reason)
        {:noreply, state}
    end
  end

  def handle_continue({:"$tenant_man", :handle_run}, %__MODULE__{} = state) do
    {:ok, tenant} = Storage.fetch(state.key)

    case state.tenant_module.handle_run({tenant, state.tenant_state}) do
      {:noreply, tenant_state} ->
        {:noreply, %{state | tenant_state: tenant_state}}

      {:noreply, tenant_state, extra} ->
        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:stop, reason, tenant_state} ->
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  def handle_continue({:"$tenant_man", {:update_async, async, config}}, %__MODULE__{} = state) do
    {:ok, tenant} = Storage.fetch(state.key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result(tenant.id)
        Storage.update(state.key, %{tenant | config: config})
        {:noreply, %{state | tenant_state: tenant_state}}

      {:error, reason} ->
        report_update_result(tenant.id, reason)
        {:noreply, state}
    end
  end

  def handle_continue(
        {:"$tenant_man", {:update_async, async, config, extra}},
        %__MODULE__{} = state
      ) do
    {:ok, tenant} = Storage.fetch(state.key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result(tenant.id)
        Storage.update(state.key, %{tenant | config: config})
        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:error, reason} ->
        report_update_result(tenant.id, reason)
        {:noreply, state, extra}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async}}, %__MODULE__{} = state) do
    {:ok, tenant} = Storage.fetch(state.key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result(tenant.id)
        {:noreply, %{state | tenant_state: tenant_state}}

      {:error, reason} ->
        report_uninstall_result(tenant.id, reason)
        {:noreply, state}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async, extra}}, %__MODULE__{} = state) do
    {:ok, tenant} = Storage.fetch(state.key)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result(tenant.id)
        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:error, reason} ->
        report_uninstall_result(tenant.id, reason)
        {:noreply, state, extra}
    end
  end

  def handle_continue(continue_arg, %__MODULE__{} = state) do
    wrap_reply(continue_arg, :handle_continue, state)
  end

  @impl GenServer
  def terminate(reason, %__MODULE__{} = state) do
    case Storage.fetch(state.key) do
      {:ok, tenant} ->
        state.tenant_module.terminate(reason, {tenant, state.tenant_state})

      :error ->
        # if the tenant is stopped before `Storage.insert`
        :ok
    end
  end

  defp build_payload(tenant_id, type, reason) do
    errors =
      if is_nil(reason) do
        []
      else
        [%{"reason" => inspect(reason)}]
      end

    %{
      type => %{
        "success" => is_nil(reason),
        "instanceId" => extract_instance_id(tenant_id),
        "errors" => errors
      }
    }
  end

  defp describe({tenant_module, tenant_id}) do
    "#{inspect(tenant_module)}<#{tenant_id}>"
  end

  defp extract_instance_id(tenant_id) do
    tenant_id
    |> JetPluginSDK.Tenant.split_tenant_id()
    |> elem(2)
  end

  defp handle_reply_callback(reply, %__MODULE__{} = state) do
    case reply do
      {:reply, reply, tenant_state} ->
        {:reply, reply, %{state | tenant_state: tenant_state}}

      {:reply, reply, tenant_state, timeout_or_hibernate_or_continue} ->
        {:reply, reply, %{state | tenant_state: tenant_state}, timeout_or_hibernate_or_continue}
    end
  end

  defp handle_noreply_callback(reply, %__MODULE__{} = state) do
    case reply do
      {:noreply, tenant_state} ->
        {:noreply, %{state | tenant_state: tenant_state}}

      {:noreply, tenant_state, timeout_or_hibernate_or_continue} ->
        {:noreply, %{state | tenant_state: tenant_state}, timeout_or_hibernate_or_continue}
    end
  end

  defp report_install_result(tenant_id, reason \\ nil) do
    tenant_id
    |> build_payload("install", reason)
    |> JetPluginSDK.JetClient.send_event()
  end

  defp report_update_result(tenant_id, reason \\ nil) do
    tenant_id
    |> build_payload("update", reason)
    |> JetPluginSDK.JetClient.send_event()
  end

  defp report_uninstall_result(tenant_id, reason \\ nil) do
    tenant_id
    |> build_payload("uninstall", reason)
    |> JetPluginSDK.JetClient.send_event()
  end

  defp run_async(async) when is_function(async, 0) do
    async.()
  end

  defp run_async({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
  end

  defp wrap_reply(request, callback, %__MODULE__{} = state) do
    {:ok, tenant} = Storage.fetch(state.key)

    case apply(state.tenant_module, callback, [request, {tenant, state.tenant_state}]) do
      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, state)

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(state.key) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end
end
