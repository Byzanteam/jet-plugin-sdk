defmodule JetPluginSDK.TenantMan do
  @moduledoc """
  The `JetPluginSDK.TenantMan` module provides a behaviour for implementing
  a tenant management supervisor.

  ## Example

      defmodule MyTenant do
        @moduledoc false

        use JetPluginSDK.TenantMan

        @spec ping(GenServer.server()) :: :pong
        def ping(server) do
          GenServer.call(server, :ping)
        end

        @impl JetPluginSDK.TenantMan
        def handle_install(_tenant) do
          {:ok, %{}}
        end

        @impl JetPluginSDK.TenantMan
        def handle_run({_tenant, tenant_state}) do
          {:ok, tenant_state}
        end

        @impl JetPluginSDK.TenantMan
        def handle_call(:ping, _from, state) do
          {:reply, :pong, state}
        end
      end


  ## Usage

      children = [
        MyTenant
      ]

      Supervisor.start_link(children, strategy: :one_for_all)
  """

  alias JetPluginSDK.Tenant
  alias JetPluginSDK.TenantMan.Registry
  alias JetPluginSDK.TenantMan.Storage

  @type naming_fun() ::
          (:registry | :storage | :tenants_supervisor -> GenServer.name())
  @type tenant_module() :: module()

  @typep tenant() :: JetPluginSDK.Tenant.t()
  @typep tenant_id() :: JetPluginSDK.Tenant.id()
  @typep tenant_config() :: JetPluginSDK.Tenant.config()
  @typep tenant_capabilities() :: JetPluginSDK.Tenant.capabilities()
  @typep tenant_state() :: term()

  @typep async() :: {module(), atom(), args :: [term()]} | function()
  @typep extra() :: {:continue, continue_arg :: term()} | :hibernate | timeout()

  @callback handle_install(tenant()) ::
              {:ok, tenant_state()}
              | {:async, async()}
              | {:error, reason :: term()}

  @callback handle_run({tenant(), tenant_state()}) ::
              {:ok, tenant_state()}
              | {:ok, tenant_state(), extra()}
              | {:error, reason :: term(), tenant_state()}
              | {:error, reason :: term(), tenant_state(), extra()}

  @callback handle_update({tenant_config(), tenant_capabilities()}, {tenant(), tenant_state()}) ::
              {:ok, tenant_state()}
              | {:ok, tenant_state(), extra()}
              | {:async, async()}
              | {:async, async(), extra()}
              | {:error, reason :: term()}
              | {:error, reason :: term(), extra()}

  @callback handle_uninstall({tenant(), tenant_state()}) ::
              {:ok, tenant_state()}
              | {:ok, tenant_state(), extra()}
              | {:async, async()}
              | {:async, async(), extra()}
              | {:error, reason :: term()}
              | {:error, reason :: term(), extra()}

  @callback handle_call(request :: term(), from :: GenServer.from(), {tenant(), tenant_state()}) ::
              {:reply, reply, tenant_state()}
              | {:reply, reply, tenant_state(), extra()}
              | {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason, reply, tenant_state()}
              | {:stop, reason, tenant_state()}
            when reply: var, reason: term()

  @callback handle_cast(request :: term(), {tenant(), tenant_state()}) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: term(), tenant_state()}

  @callback handle_continue(continue_arg :: term(), {tenant(), tenant_state()}) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: term(), tenant_state()}

  @callback handle_info(msg :: :timeout | term(), {tenant(), tenant_state()}) ::
              {:noreply, tenant_state()}
              | {:noreply, tenant_state(), extra()}
              | {:stop, reason :: term(), tenant_state()}

  @callback terminate(reason, {tenant(), tenant_state()}) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()} | term()

  @optional_callbacks handle_call: 3,
                      handle_cast: 2,
                      handle_continue: 2,
                      handle_info: 2,
                      handle_update: 2,
                      handle_uninstall: 1,
                      terminate: 2

  defmacro __using__(opts) do
    quote do
      @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @spec start_link(Keyword.t()) :: Supervisor.on_start()
      def start_link(opts) do
        opts =
          unquote(opts)
          |> Keyword.merge(opts)
          |> Keyword.merge(tenant_module: __MODULE__)
          |> Keyword.put_new(:name, __MODULE__)
          |> Keyword.put(:naming_fun, &default_naming_fun/1)

        JetPluginSDK.TenantMan.Supervisor.start_link(opts)
      end

      defp default_naming_fun(:registry), do: Module.concat(__MODULE__, Registry)
      defp default_naming_fun(:storage), do: Module.concat(__MODULE__, Storage)

      defp default_naming_fun(:tenants_supervisor),
        do: Module.concat(__MODULE__, Tenants.Supervisor)

      # Callbacks
      @behaviour unquote(__MODULE__)

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

      @typep tenant() :: JetPluginSDK.Tenant.t()
      @typep tenant_id() :: JetPluginSDK.Tenant.id()
      @typep tenant_config() :: JetPluginSDK.Tenant.config()
      @typep tenant_capabilities() :: JetPluginSDK.Tenant.capabilities()

      # Life-cycle APIs
      @spec install(tenant()) :: :ok | :async | {:error, reason :: term()}
      def install(tenant) do
        unquote(__MODULE__).install(&default_naming_fun/1, tenant)
      end

      @spec update(tenant_id(), {tenant_config(), tenant_capabilities()}) ::
              :ok | :async | {:error, reason :: term()}
      def update(tenant_id, {config, capabilities}) do
        unquote(__MODULE__).update(&default_naming_fun/1, tenant_id, {config, capabilities})
      end

      @spec uninstall(tenant_id()) :: :ok | :async | {:error, reason :: term()}
      def uninstall(tenant_id) do
        unquote(__MODULE__).uninstall(&default_naming_fun/1, tenant_id)
      end

      # Helpers
      @spec whereis(tenant_id()) :: {:ok, pid()} | :error
      def whereis(tenant_id) do
        unquote(__MODULE__).whereis(&default_naming_fun/1, tenant_id)
      end

      @spec fetch!(tenant_id()) :: tenant()
      def fetch!(tenant_id) do
        unquote(__MODULE__).fetch_tenant!(&default_naming_fun/1, tenant_id)
      end
    end
  end

  @spec install(naming_fun(), tenant()) ::
          {:ok, pid()} | {:error, :arleady_exists | :invalid_state | term()}
  def install(naming_fun, %Tenant{state: :installing} = tenant) do
    case Storage.insert(naming_fun, tenant) do
      {:ok, pid} ->
        GenServer.call(pid, {:"$tenant_man", :install, tenant})

      {:error, :already_exists} = error ->
        error
    end
  end

  def install(_naming_fun, %Tenant{}) do
    {:error, :invalid_state}
  end

  @spec update(naming_fun(), tenant_id(), {tenant_config(), tenant_capabilities()}) ::
          :ok | :async | {:error, term()}
  def update(naming_fun, tenant_id, {config, capabilities}) do
    case Registry.whereis(naming_fun, tenant_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:"$tenant_man", {:update, config, capabilities}})

      :error ->
        {:error, :tenant_not_found}
    end
  end

  @spec uninstall(naming_fun(), tenant_id()) :: term()
  def uninstall(naming_fun, tenant_id) do
    case Registry.whereis(naming_fun, tenant_id) do
      {:ok, pid} -> GenServer.call(pid, {:"$tenant_man", :uninstall})
      :error -> {:error, :tenant_not_found}
    end
  end

  @spec whereis(naming_fun(), tenant_id()) :: {:ok, pid()} | :error
  def whereis(naming_fun, tenant_id) do
    Registry.whereis(naming_fun, tenant_id)
  end

  @spec fetch_tenant!(naming_fun(), tenant_id()) :: tenant()
  def fetch_tenant!(naming_fun, tenant_id) do
    case Storage.fetch(naming_fun, tenant_id) do
      {:ok, tenant} -> tenant
      :error -> raise "The tenant with id(#{inspect(tenant_id)}) is not found"
    end
  end
end