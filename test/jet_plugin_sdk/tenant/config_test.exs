defmodule JetPluginSdk.Tenant.ConfigTest do
  use ExUnit.Case, async: true

  alias JetPluginSDK.Tenant.Config

  describe "from_json/1" do
    test "works" do
      config = %{
        string: "bar",
        number: 1,
        number_list: [1, 2, 3],
        string_list: ["foo", "bar"],
        object: %{
          string: "foo",
          number: 2
        },
        object_list: [
          %{
            string: "foo",
            number: 2
          },
          %{
            string: "bar",
            number: 3
          }
        ]
      }

      json = config |> Jason.encode!() |> Jason.decode!()

      assert config === Config.from_json(json)
    end

    test "converts camelCase keys to snake_case atoms" do
      config = %{
        camelCaseKey: "foo",
        nestedObject: %{
          anotherCamelCaseKey: "bar"
        }
      }

      json = config |> Jason.encode!() |> Jason.decode!()

      assert %{
               camel_case_key: "foo",
               nested_object: %{
                 another_camel_case_key: "bar"
               }
             } === Config.from_json(json)
    end
  end
end
