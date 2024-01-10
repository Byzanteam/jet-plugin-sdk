defmodule JetPluginSDK.TenantMan.Registry do
  @moduledoc false

  @type start_child_spec() :: {module(), Keyword.t()} | module()

  @spec start_child(
          name :: term(),
          dynamic_supervisor :: Supervisor.supervisor(),
          child_spec :: start_child_spec()
        ) :: DynamicSupervisor.on_start_child()
  def start_child(name, supervisor, child_spec) do
    via_name = via_tuple(name)

    child_spec =
      case child_spec do
        module when is_atom(module) ->
          {module, name: via_name}

        {module, args} when is_atom(module) and is_list(args) ->
          {module, Keyword.put(args, :name, via_name)}
      end

    DynamicSupervisor.start_child(supervisor, child_spec)
  end

  @spec via_tuple(name :: term()) :: tuple()
  def via_tuple(name) do
    {:via, Registry, {name(), name}}
  end

  @spec whereis_name(name :: term()) :: {:ok, pid()} | :error
  def whereis_name(name) do
    case Registry.lookup(name(), name) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_arg) do
    Registry.child_spec(keys: :unique, name: name())
  end

  defp name, do: __MODULE__
end
