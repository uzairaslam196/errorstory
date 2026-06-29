defmodule ErrorStory.Integrations.PostHog.Api do
  @moduledoc """
  Raw PostHog API client.
  """

  alias ErrorStory.Config
  alias ErrorStory.Request

  @doc """
  Fetches events for a distinct user or session id.

  ## Parameters

    * `distinct_id` - PostHog distinct id.
    * `opts` - optional `:base_url`, `:project_id`, and `:api_key`.

  ## Returns

  `{:ok, map()}` or `{:error, reason}`.
  """
  @spec fetch_events(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fetch_events(distinct_id, opts \\ []) when is_binary(distinct_id) do
    base_url =
      Keyword.get(opts, :base_url) || Config.get(:post_hog_base_url, "https://app.posthog.com")

    project_id = Keyword.get(opts, :project_id) || Config.fetch!(:post_hog_project_id)
    api_key = Keyword.get(opts, :api_key) || Config.fetch!(:post_hog_api_key)

    client =
      Request.new(
        base_url: base_url,
        headers: [{"authorization", "Bearer #{api_key}"}],
        params: [distinct_id: distinct_id]
      )

    with {:ok, %{body: body}} <- Request.get(client, "/api/projects/#{project_id}/events/") do
      {:ok, body}
    end
  end
end
