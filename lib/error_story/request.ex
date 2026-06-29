defmodule ErrorStory.Request do
  @moduledoc """
  Central HTTP wrapper for provider integrations.

  Provider `Api` modules build clients with `new/1` and call this module for
  HTTP. Test configuration injects `Req.Test` options so normal tests do not
  hit the network.
  """

  require Logger

  @doc """
  Creates a reusable Req client.

  ## Parameters

    * `opts` - options passed to `Req.new/1`.

  ## Returns

  A `%Req.Request{}`.
  """
  @spec new(keyword()) :: Req.Request.t()
  def new(opts \\ []) do
    test_opts = Application.get_env(:error_story, :req_options, [])
    Req.new(opts ++ test_opts)
  end

  @doc """
  Makes a GET request with a client.

  ## Parameters

    * `client` - request client from `new/1`.
    * `path` - relative path.
    * `opts` - per-call options.

  ## Returns

  `{:ok, %{status: integer(), body: term()}}` or `{:error, reason}`.
  """
  @spec get(Req.Request.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%Req.Request{} = client, path, opts \\ []) when is_binary(path) do
    execute(Req.merge(client, Keyword.merge(opts, url: path)), :get)
  end

  @doc """
  Makes a POST request with a JSON body.

  ## Parameters

    * `client` - request client from `new/1`.
    * `path` - relative path.
    * `body` - JSON body.
    * `opts` - per-call options.

  ## Returns

  `{:ok, %{status: integer(), body: term()}}` or `{:error, reason}`.
  """
  @spec post(Req.Request.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(%Req.Request{} = client, path, body, opts \\ [])
      when is_binary(path) and is_map(body) do
    request_opts = opts |> Keyword.put(:url, path) |> Keyword.put(:json, body)
    execute(Req.merge(client, request_opts), :post)
  end

  defp execute(%Req.Request{} = request, method) do
    case Req.request(request, method: method) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, %{status: status, body: body}}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("ErrorStory HTTP #{method} returned status=#{status}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("ErrorStory HTTP #{method} failed")
        {:error, reason}
    end
  end
end
