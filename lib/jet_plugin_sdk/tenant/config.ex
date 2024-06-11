defmodule JetPluginSDK.Tenant.Config do
  @moduledoc """
  The config that is defined by the plugin.
  """

  @type t() :: %{atom() => term()}

  @spec from_json(map()) :: t()
  def from_json(map) when is_map(map) do
    do_from_json(map)
  end

  defp do_from_json(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {key |> Macro.underscore() |> String.to_existing_atom(), do_from_json(value)}
    end)
  end

  defp do_from_json(list) when is_list(list) do
    Enum.map(list, &do_from_json/1)
  end

  defp do_from_json(value) do
    value
  end
end
