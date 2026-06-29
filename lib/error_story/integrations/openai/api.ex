defmodule ErrorStory.Integrations.OpenAI.Api do
  @moduledoc """
  Raw OpenAI HTTP client.
  """

  alias ErrorStory.Config
  alias ErrorStory.Request

  @base_url "https://api.openai.com/v1/"

  @doc """
  Posts a chat-completions request.

  ## Parameters

    * `request_body` - OpenAI request body.
    * `opts` - optional client overrides.

  ## Returns

  `{:ok, map()}` or `{:error, reason}`.
  """
  @spec post_chat_completions(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post_chat_completions(request_body, opts \\ []) when is_map(request_body) do
    api_key = Keyword.get(opts, :api_key) || Config.fetch!(:openai_api_key)

    client =
      Request.new(
        base_url: @base_url,
        headers: [{"authorization", "Bearer #{api_key}"}],
        receive_timeout: 180_000
      )

    with {:ok, %{body: body}} <- Request.post(client, "chat/completions", request_body) do
      {:ok, body}
    end
  end
end
