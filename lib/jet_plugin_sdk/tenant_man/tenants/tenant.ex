defmodule JetPluginSDK.TenantMan.Tenants.Tenant do
  @moduledoc false

  use GenServer

  require Logger

  @typep tenant_schema() :: JetPluginSDK.Tenant.t()
  @typep tenant_id() :: JetPluginSDK.Tenant.tenant_id()
  @typep tenant_config() :: JetPluginSDK.Tenant.config()

  @type state() :: term()

  @callback init(tenant :: tenant_schema()) ::
              {:ok, tenant_schema(), state()}
              | {:ok, tenant_schema(), state(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | :ignore
              | {:stop, reason :: any()}

  @callback handle_config_updation(
              new_config :: tenant_config(),
              from :: GenServer.from(),
              state()
            ) ::
              {:reply, reply, config :: tenant_config(), state()}
              | {:reply, reply, config :: tenant_config(), state(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:noreply, config :: tenant_config(), state()}
              | {:noreply, config :: tenant_config(), state(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason, reply, state()}
              | {:stop, reason, state()}
            when reply: term(), reason: any()

  @callback handle_call(request :: term(), from :: GenServer.from(), state()) ::
              {:reply, reply, state()}
              | {:reply, reply, state(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:noreply, state()}
              | {:noreply, state(), timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason, reply, state()}
              | {:stop, reason, state()}
            when reply: term(), reason: any()

  @callback handle_cast(request :: term(), state()) ::
              {:noreply, state()}
              | {:noreply, state(), timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason :: any(), state()}

  @callback handle_continue(continue_arg :: term(), state()) ::
              {:noreply, state()}
              | {:noreply, state(), timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason :: any(), state()}

  @callback handle_info(msg :: :timeout | term(), state()) ::
              {:noreply, state()}
              | {:noreply, state(), timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason :: any(), state()}

  @callback terminate(reason, state :: state()) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()} | term()

  @optional_callbacks handle_config_updation: 3,
                      handle_call: 3,
                      handle_cast: 2,
                      handle_continue: 2,
                      handle_info: 2,
                      terminate: 2

  defmacro __using__(_opts) do
    quote location: :keep do
      @typep start_link_opts() :: [
               tenant_id: JetPluginSDK.Tenant.tenant_id(),
               tenant: JetPluginSDK.Tenant.t(),
               name: unquote(__MODULE__).name()
             ]

      @spec start_link(start_link_opts()) :: GenServer.on_start()
      def start_link(opts) do
        opts = Keyword.put(opts, :tenant_module, __MODULE__)
        unquote(__MODULE__).start_link(opts)
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

      defoverridable child_spec: 1

      @behaviour JetPluginSDK.TenantMan.Tenants.Tenant
    end
  end

  @enforce_keys [:tenant_id, :tenant_module, :tenant]
  defstruct [
    :tenant_id,
    :tenant_module,
    :tenant,
    :tenant_state
  ]

  @type t() :: %__MODULE__{
          tenant_id: tenant_id(),
          tenant_module: module(),
          tenant: tenant_schema(),
          tenant_state: state()
        }

  @type name() :: {module(), tenant_id()}

  @type start_link_opts() :: [
          tenant_id: tenant_id(),
          tenant_module: module(),
          tenant: tenant_schema(),
          name: name()
        ]

  @spec name(tenant_module :: module(), tenant_id()) :: name()
  def name(tenant_module, tenant_id) do
    {tenant_module, tenant_id}
  end

  @spec fetch_tenant(tenant_module :: module(), tenant_id()) :: {:ok, tenant_schema()} | :error
  def fetch_tenant(tenant_module, tenant_id) do
    with(
      {:ok, pid} <-
        JetPluginSDK.TenantMan.Tenants.Supervisor.whereis_tenant(tenant_id, tenant_module)
    ) do
      GenServer.call(pid, {:"$tenant_man", :fetch_tenant})
    end
  end

  @spec update_config(tenant_module :: module(), tenant_id(), new_config :: tenant_config()) ::
          term()
  def update_config(tenant_module, tenant_id, new_config) do
    case JetPluginSDK.TenantMan.Tenants.Supervisor.whereis_tenant(tenant_id, tenant_module) do
      {:ok, pid} ->
        GenServer.call(pid, {:"$tenant_man", {:update_config, new_config}})

      :error ->
        {:error, :tenant_not_found}
    end
  end

  @spec start_link(start_link_opts()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop!(opts, :name)

    GenServer.start_link(__MODULE__, __struct__(opts), name: name)
  end

  @impl GenServer
  def init(%__MODULE__{} = state) do
    Logger.debug(describe(state) <> " is started.")

    case state.tenant_module.init(state.tenant) do
      {:ok, tenant, tenant_state} ->
        Logger.debug(describe(state) <> " is initialized with tenant: #{inspect(tenant)}.")
        {:ok, %{state | tenant: tenant, tenant_state: tenant_state}}

      {:ok, tenant, tenant_state, timeout_or_hibernate_or_continue} ->
        Logger.debug(describe(state) <> " is initialized with tenant: #{inspect(tenant)}.")

        {:ok, %{state | tenant: tenant, tenant_state: tenant_state},
         timeout_or_hibernate_or_continue}

      :ignore ->
        :ignore

      {:stop, reason} ->
        Logger.debug(describe(state) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:"$tenant_man", :fetch_tenant}, _from, %__MODULE__{} = state) do
    {:reply, {:ok, state.tenant}, state}
  end

  @impl GenServer
  def handle_call({:"$tenant_man", {:update_config, new_config}}, from, %__MODULE__{} = state) do
    Logger.debug(
      describe(state) <> " is updating config with new config: #{inspect(new_config)}."
    )

    case state.tenant_module.handle_config_updation(new_config, from, state.tenant_state) do
      reply when is_tuple(reply) and tuple_size(reply) in [4, 5] and elem(reply, 0) === :reply ->
        [:reply, reply, config | extra_args] = Tuple.to_list(reply)
        state = Map.update!(state, :tenant, &Map.put(&1, :config, config))
        reply = List.to_tuple([:reply, reply | extra_args])

        Logger.debug(describe(state) <> " is updated with new config: #{inspect(config)}.")

        handle_reply_callback(reply, state)

      reply
      when is_tuple(reply) and tuple_size(reply) in [3, 4] and elem(reply, 0) === :noreply ->
        [:noreply, config | extra_args] = Tuple.to_list(reply)
        state = Map.update!(state, :tenant, &Map.put(&1, :config, config))
        reply = List.to_tuple([:noreply | extra_args])

        Logger.debug(describe(state) <> " is updated with new config: #{inspect(config)}.")

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
  def handle_call(request, from, %__MODULE__{} = state) do
    case state.tenant_module.handle_call(request, from, state.tenant_state) do
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
  def handle_continue(continue_arg, %__MODULE__{} = state) do
    wrap_reply(continue_arg, state.tenant_module, :handle_continue, state)
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
    case apply(tenant_module, callback, [request, state.tenant_state]) do
      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, state)

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(state) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  @impl GenServer
  def terminate(reason, %__MODULE__{} = state) do
    state.tenant_module.terminate(reason, state.tenant_state)
  end

  defp describe(%__MODULE__{} = state) do
    %{
      tenant_id: tenant_id,
      tenant_module: tenant_module
    } = state

    "#{inspect(tenant_module)}<#{tenant_id}>"
  end
end
