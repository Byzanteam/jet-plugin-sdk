defmodule JetPluginSDK.TenantMan.Tenants.Tenant do
  @moduledoc false

  use GenServer, restart: :temporary

  require Logger

  alias JetPluginSDK.TenantMan.Storage

  @enforce_keys [:naming_fun, :tenant_module, :tenant_id]
  defstruct [:naming_fun, :tenant_module, :tenant_id, :tenant_state]

  @typep naming_fun() :: JetPluginSDK.TenantMan.naming_fun()
  @typep tenant_module() :: JetPluginSDK.TenantMan.tenant_module()
  @typep tenant_id() :: JetPluginSDK.Tenant.id()

  @spec start_link(
          [tenant_module: tenant_module()],
          name: GenServer.name(),
          naming_fun: naming_fun(),
          tenant_id: tenant_id()
        ) :: GenServer.on_start()
  def start_link(extra_args, opts) do
    {name, opts} = Keyword.pop!(opts, :name)

    GenServer.start_link(__MODULE__, Keyword.merge(extra_args, opts), name: name)
  end

  @impl GenServer
  def init(opts) do
    tenant_module = Keyword.fetch!(opts, :tenant_module)
    naming_fun = Keyword.fetch!(opts, :naming_fun)
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    tenant = Storage.fetch!(naming_fun, tenant_id)

    state = __struct__(naming_fun: naming_fun, tenant_id: tenant.id, tenant_module: tenant_module)

    case tenant.state do
      :installing ->
        {:ok, state}

      :running ->
        {:ok, state, {:continue, {:"$tenant_man", :handle_run}}}

      :error_occurred ->
        {:ok, state}

      _state ->
        {:error, :unexpected_state}
    end
  end

  @impl GenServer
  def handle_call({:"$tenant_man", :install, tenant}, _from, %__MODULE__{} = state) do
    Logger.debug(describe(state) <> " is installing.")

    case state.tenant_module.handle_install(tenant) do
      {:ok, tenant_state} ->
        Storage.update!(state.naming_fun, %{tenant | state: :running})

        {
          :reply,
          :ok,
          %{state | tenant_state: tenant_state},
          {:continue, {:"$tenant_man", :handle_run}}
        }

      {:async, async} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:install_async, async}}}}

      {:error, reason} ->
        {:stop, reason, {:error, reason}, state}
    end
  end

  def handle_call({:"$tenant_man", {:update, config, capabilities}}, _from, %__MODULE__{} = state) do
    Logger.debug(
      describe(state) <>
        " is updating config with new config: #{inspect(config)} and capabilities #{inspect(capabilities)}."
    )

    tenant = fetch_tenant!(state)

    case state.tenant_module.handle_update({config, capabilities}, {tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        Storage.update!(state.naming_fun, %{
          tenant
          | config: config,
            capabilities: capabilities
        })

        {:reply, :ok, %{state | tenant_state: tenant_state}}

      {:ok, tenant_state, extra} ->
        Storage.update!(state.naming_fun, %{
          tenant
          | config: config,
            capabilities: capabilities
        })

        {:reply, :ok, %{state | tenant_state: tenant_state}, extra}

      {:async, async} ->
        {
          :reply,
          :async,
          state,
          {:continue, {:"$tenant_man", {:update_async, async, {config, capabilities}}}}
        }

      {:async, async, extra} ->
        {
          :reply,
          :async,
          state,
          {:continue, {:"$tenant_man", {:update_async, async, {config, capabilities}, extra}}}
        }

      {:error, reason} ->
        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:reply, {:error, reason}, state}

      {:error, reason, extra} ->
        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:reply, {:error, reason}, state, extra}
    end
  end

  def handle_call({:"$tenant_man", :uninstall}, _from, %__MODULE__{} = state) do
    Logger.debug(describe(state) <> " is uninstalling.")

    tenant = fetch_tenant!(state)

    case state.tenant_module.handle_uninstall({tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        Storage.update!(state.naming_fun, %{tenant | state: :uninstalled})

        {:stop, :normal, :ok, %{state | tenant_state: tenant_state}}

      {:ok, tenant_state, extra} ->
        Storage.update!(state.naming_fun, %{tenant | state: :uninstalled})

        {:reply, :ok, %{state | tenant_state: tenant_state}, extra}

      {:async, async} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:uninstall_async, async}}}}

      {:async, async, extra} ->
        {:reply, :async, state, {:continue, {:"$tenant_man", {:uninstall_async, async, extra}}}}

      {:error, reason} ->
        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:reply, {:error, reason}, state}

      {:error, reason, extra} ->
        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:reply, {:error, reason}, state, extra}
    end
  end

  @impl GenServer
  def handle_call(request, from, %__MODULE__{} = state) do
    tenant = fetch_tenant!(state)

    case state.tenant_module.handle_call(request, from, {tenant, state.tenant_state}) do
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
  def handle_cast(request, %__MODULE__{} = state) do
    wrap_reply(request, :handle_cast, state)
  end

  @impl GenServer
  def handle_info(msg, %__MODULE__{} = state) do
    wrap_reply(msg, :handle_info, state)
  end

  @impl GenServer
  def handle_continue({:"$tenant_man", {:install_async, async}}, %__MODULE__{} = state) do
    tenant = fetch_tenant!(state)

    case run_async(async) do
      {:ok, tenant_state} ->
        # TDOO: handle failure
        report_install_result(tenant.id)

        Storage.update!(state.naming_fun, %{tenant | state: :running})

        {
          :noreply,
          %{state | tenant_state: tenant_state},
          {:continue, {:"$tenant_man", :handle_run}}
        }

      {:error, reason} ->
        # TDOO: handle failure
        report_install_result(tenant.id, reason)

        {:stop, reason, state}
    end
  end

  def handle_continue({:"$tenant_man", :handle_run}, %__MODULE__{} = state) do
    tenant = fetch_tenant!(state)

    case state.tenant_module.handle_run({tenant, state.tenant_state}) do
      {:ok, tenant_state} ->
        {:noreply, %{state | tenant_state: tenant_state}}

      {:ok, tenant_state, extra} ->
        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:error, reason, tenant_state} ->
        report_error_occurred(tenant.id, reason)

        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:noreply, %{state | tenant_state: tenant_state}}

      {:error, reason, tenant_state, extra} ->
        report_error_occurred(tenant.id, reason)

        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:noreply, %{state | tenant_state: tenant_state}, extra}
    end
  end

  def handle_continue(
        {:"$tenant_man", {:update_async, async, {config, capabilities}}},
        %__MODULE__{} = state
      ) do
    tenant = fetch_tenant!(state)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result(tenant.id)

        Storage.update!(state.naming_fun, %{
          tenant
          | config: config,
            capabilities: capabilities
        })

        {:noreply, %{state | tenant_state: tenant_state}}

      {:error, reason} ->
        report_update_result(tenant.id, reason)

        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:noreply, state}
    end
  end

  def handle_continue(
        {:"$tenant_man", {:update_async, async, {config, capabilities}, extra}},
        %__MODULE__{} = state
      ) do
    tenant = fetch_tenant!(state)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_update_result(tenant.id)

        Storage.update!(state.naming_fun, %{
          tenant
          | config: config,
            capabilities: capabilities
        })

        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:error, reason} ->
        report_update_result(tenant.id, reason)

        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:noreply, state, extra}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async}}, %__MODULE__{} = state) do
    tenant = fetch_tenant!(state)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result(tenant.id)

        Storage.update!(state.naming_fun, %{tenant | state: :uninstalled})

        {:stop, :normal, %{state | tenant_state: tenant_state}}

      {:error, reason} ->
        report_uninstall_result(tenant.id, reason)

        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:noreply, state}
    end
  end

  def handle_continue({:"$tenant_man", {:uninstall_async, async, extra}}, %__MODULE__{} = state) do
    tenant = fetch_tenant!(state)

    case run_async(async) do
      {:ok, tenant_state} ->
        report_uninstall_result(tenant.id)

        Storage.update!(state.naming_fun, %{tenant | state: :uninstalled})

        {:noreply, %{state | tenant_state: tenant_state}, extra}

      {:error, reason} ->
        report_uninstall_result(tenant.id, reason)

        Storage.update!(state.naming_fun, %{tenant | state: :error_occurred})

        {:noreply, state, extra}
    end
  end

  def handle_continue(continue_arg, %__MODULE__{} = state) do
    wrap_reply(continue_arg, :handle_continue, state)
  end

  @impl GenServer
  def terminate(reason, %__MODULE__{} = state) do
    case Storage.fetch(state.naming_fun, state.tenant_id) do
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

  defp report_error_occurred(tenant_id, reason) do
    tenant_id
    |> build_payload("error_occurred", reason)
    |> JetPluginSDK.JetClient.send_event()
  end

  defp run_async(async) when is_function(async, 0) do
    async.()
  end

  defp run_async({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
  end

  defp wrap_reply(request, callback, %__MODULE__{} = state) do
    tenant = fetch_tenant!(state)

    case apply(state.tenant_module, callback, [request, {tenant, state.tenant_state}]) do
      reply
      when is_tuple(reply) and tuple_size(reply) in [2, 3] and elem(reply, 0) === :noreply ->
        handle_noreply_callback(reply, state)

      {:stop, reason, tenant_state} ->
        Logger.debug(describe(state) <> " is stopped with reason: #{inspect(reason)}.")
        {:stop, reason, %{state | tenant_state: tenant_state}}
    end
  end

  defp fetch_tenant!(%__MODULE__{} = state) do
    Storage.fetch!(state.naming_fun, state.tenant_id)
  end

  defp describe(%__MODULE__{} = state) do
    "#{inspect(state.tenant_module)}<#{state.tenant_id}>"
  end
end
