defmodule JetPluginSDK.GraphQLClient do
  @moduledoc false

  @typep query_opts() :: [
           variables: map(),
           headers: [{binary(), binary()}],
           timeout: pos_integer(),
           max_retries: non_neg_integer()
         ]

  @type error() :: Exception.t()

  @spec query(url :: binary() | URI.t(), query_string :: String.t(), query_opts()) ::
          {:ok, Req.Response.t()} | {:error, error()}
  def query(url, query_string, opts \\ []) do
    {timeout, opts} = Keyword.pop(opts, :timeout, 15_000)
    {variables, opts} = Keyword.pop(opts, :variables, %{})

    [
      url: url,
      connect_options: [timeout: timeout],
      retry: :transient,
      json: %{query: query_string, variables: variables}
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    # https://graphql.github.io/graphql-over-http/draft/#sec-Legacy-Watershed
    |> Req.Request.put_header(
      "accept",
      "application/graphql-response+json; charset=utf-8, application/json; charset=utf-8"
    )
    |> Req.post()
  end
end
