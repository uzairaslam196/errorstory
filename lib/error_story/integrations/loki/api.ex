defmodule ErrorStory.Integrations.Loki.Api do
  @moduledoc """
  Raw Loki HTTP client.
  """

  alias ErrorStory.Config
  alias ErrorStory.Request

  @doc """
  Queries Loki's range endpoint.

  ## Parameters

    * `query` - LogQL query.
    * `opts` - optional `:base_url`, `:start`, `:end`, and `:limit`.

  ## Returns

  `{:ok, map()}` or `{:error, reason}`.
  """
  @spec query_range(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def query_range(query, opts \\ []) when is_binary(query) do
    base_url = Keyword.get(opts, :base_url) || Config.fetch!(:loki_base_url)

    params =
      opts
      |> Keyword.take([:start, :end, :limit])
      |> Keyword.put(:query, query)

    client = Request.new(base_url: base_url, params: params)

    with {:ok, %{body: body}} <- Request.get(client, "/loki/api/v1/query_range") do
      {:ok, body}
    end
  end
end
