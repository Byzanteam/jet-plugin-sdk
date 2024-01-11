defmodule JetPluginSDK.TenantMan.Supervisor do
  @moduledoc false

  use Supervisor

  @type start_opts() :: [warm_up: JetPluginSDK.TenantMan.WarmUp.start_opts()]

  @spec start_link(start_opts()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    warm_up_children =
      if warm_up_opts = Keyword.get(opts, :warm_up) do
        [{JetPluginSDK.TenantMan.WarmUp, warm_up_opts}]
      else
        []
      end

    children =
      [
        JetPluginSDK.TenantMan.Registry,
        JetPluginSDK.TenantMan.Tenants.Supervisor
      ] ++ warm_up_children

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
