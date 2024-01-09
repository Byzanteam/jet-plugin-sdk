defmodule JetPluginSDK.GraphQLClient do
  @moduledoc false

  @type query_opts() :: [
          variables: map(),
          headers: [{binary(), binary()}],
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          retry_init_delay: pos_integer()
        ]

  @type error() ::
          Mint.Types.error()
          | Jason.EncodeError.t()
          | Jason.DecodeError.t()
          | %Protocol.UndefinedError{}
          | %RuntimeError{}
          | %ErlangError{}

  @spec query(url :: binary() | URI.t(), query_string :: String.t(), query_opts()) ::
          {:ok, Req.Response.t()} | {:error, error()}
  def query(url, query_string, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 15_000)
    variables = Keyword.get(opts, :variables, %{})

    req =
      [url: url, connect_options: [timeout: timeout]]
      |> Req.new()
      |> AbsintheClient.attach(graphql: {query_string, variables})
      |> accept_graphql_json()
      |> put_retry_opts(opts)

    with({:ok, %Req.Response{status: 200} = response} <- Req.post(req)) do
      decode_body(response)
    end
  rescue
    # 可能会抛出的异常
    # request_steps: `encode_body` may raise `Protocol.UndefinedError` or `Jason.EncodeError`
    # response_steps: `follow_redirects` may raise `"too many redirects (#{max_redirects})"`
    # resopnse_steps: `decompress_body` may raise %ErlangError{original: :data_error}
    e in [Jason.EncodeError] ->
      {:error, e}

    e in [Protocol.UndefinedError] ->
      if Jason.Encoder === e.protocol do
        {:error, e}
      else
        reraise e, __STACKTRACE__
      end

    e in [RuntimeError] ->
      if String.starts_with?(e.message, "too many redirects (") do
        {:error, e}
      else
        reraise e, __STACKTRACE__
      end

    e in [ErlangError] ->
      if :data_error === e.original do
        {:error, e}
      else
        reraise e, __STACKTRACE__
      end

    e ->
      reraise e, __STACKTRACE__
  end

  defp accept_graphql_json(request) do
    request
    # Req 会在请求错误时也 decode_body，并且 decode JSON 时使用的是 `Jason.decode!/1`
    # 我们这里要避免这种行为：
    # 1. 只在请求成功时才去 decode
    # 2. decode JSON 失败时返回错误而不是抛出异常
    |> Req.Request.merge_options(decode_body: false)
    # https://graphql.github.io/graphql-over-http/draft/#sec-Legacy-Watershed
    |> Req.Request.prepend_request_steps(
      accept_json:
        &Req.Request.put_header(
          &1,
          "accept",
          "application/graphql-response+json; charset=utf-8, application/json; charset=utf-8"
        )
    )
  end

  defp put_retry_opts(request, opts) do
    case Keyword.get(opts, :max_retries, 3) do
      max_retries when is_integer(max_retries) and max_retries > 0 ->
        Req.Request.merge_options(request,
          retry: &should_retry?/1,
          # Req 自带的 exp_backoff 不支持指定初始值
          retry_delay: &exp_backoff(&1, Keyword.get(opts, :retry_init_delay, 1_000)),
          max_retries: max_retries
        )

      _otherwise ->
        Req.Request.merge_options(request, retry: false)
    end
  end

  defp should_retry?(response_or_exception) do
    case response_or_exception do
      # 当 server 系统错误时 retry
      %Req.Response{status: status} when status in [408, 429] or status in 500..599 ->
        true

      # 其它的错误，例如 403/404 不应该 retry
      %Req.Response{} ->
        false

      # 网络错误时 retry
      exception when is_exception(exception) ->
        true
    end
  end

  defp exp_backoff(n, init) do
    Integer.pow(2, n) * init
  end

  defp decode_body(response) do
    with({:ok, body} <- Jason.decode(response.body)) do
      {:ok, %{response | body: body}}
    end
  end
end
