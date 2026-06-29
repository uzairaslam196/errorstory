defmodule ErrorStory.Integrations.Sentry.Context do
  @moduledoc """
  Sentry normalization layer.

  Converts Sentry webhook payloads into `%ErrorStory.Incident{}`. Raw HTTP and
  signature details stay in `ErrorStory.Integrations.Sentry.Api`.
  """

  @behaviour ErrorStory.Integrations.ErrorTracker

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @impl ErrorStory.Integrations.ErrorTracker
  @doc """
  Normalizes a Sentry webhook payload into an incident.

  ## Parameters

    * `payload` - decoded Sentry webhook payload.
    * `opts` - optional metadata.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` or `{:error, reason}`.
  """
  @spec normalize_webhook(map(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
  def normalize_webhook(payload, opts \\ []) when is_map(payload) do
    issue = Map.get(payload, "data", %{}) |> Map.get("issue", %{})
    event = Map.get(payload, "data", %{}) |> Map.get("event", %{})

    title =
      first_present([
        Map.get(issue, "title"),
        Map.get(event, "title"),
        Map.get(event, "message"),
        Map.get(payload, "action")
      ])

    with {:ok, error_evidence} <- error_evidence(payload, issue, event) do
      Incident.new(
        id: to_string(first_present([Map.get(issue, "id"), Map.get(event, "event_id")])),
        source: :sentry,
        title: title || "Sentry error",
        service: Keyword.get(opts, :service),
        environment:
          first_present([Map.get(event, "environment"), Keyword.get(opts, :environment)]),
        release: first_present([Map.get(event, "release"), Map.get(issue, "firstRelease")]),
        fingerprint: fingerprint(issue, event),
        request_id: request_id(event),
        trace_id: trace_id(event),
        user_id: user_id(event),
        route: route(event),
        error: Map.get(event, "exception", %{}),
        stacktrace: stacktrace(event),
        metadata: %{
          action: Map.get(payload, "action"),
          project: Map.get(payload, "installation", %{}) |> Map.get("uuid")
        },
        evidence: [error_evidence],
        links: sentry_links(issue, event)
      )
    end
  end

  defp error_evidence(payload, issue, event) do
    Evidence.new(
      type: :error,
      source: :sentry,
      summary:
        first_present([Map.get(issue, "title"), Map.get(event, "message"), "Sentry error"]),
      payload: %{
        issue: issue,
        event: event,
        action: Map.get(payload, "action")
      },
      links: sentry_links(issue, event)
    )
  end

  defp fingerprint(issue, event) do
    first_present([
      issue |> Map.get("metadata", %{}) |> Map.get("fingerprint"),
      Map.get(issue, "id"),
      Map.get(event, "fingerprint")
    ])
  end

  defp request_id(event) do
    event
    |> Map.get("contexts", %{})
    |> Map.get("trace", %{})
    |> Map.get("data", %{})
    |> Map.get("request_id")
  end

  defp trace_id(event) do
    event
    |> Map.get("contexts", %{})
    |> Map.get("trace", %{})
    |> Map.get("trace_id")
  end

  defp user_id(event) do
    event
    |> Map.get("user", %{})
    |> Map.get("id")
  end

  defp route(event) do
    event
    |> Map.get("request", %{})
    |> Map.get("url")
  end

  defp stacktrace(event) do
    event
    |> Map.get("exception", %{})
    |> Map.get("values", [])
    |> Enum.flat_map(fn exception ->
      Map.get(exception, "stacktrace", %{}) |> Map.get("frames", [])
    end)
  end

  defp sentry_links(issue, event) do
    [Map.get(issue, "permalink"), Map.get(event, "web_url")]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&%{source: :sentry, url: &1})
  end

  defp first_present(values) do
    Enum.find(values, fn value -> value not in [nil, ""] end)
  end
end
