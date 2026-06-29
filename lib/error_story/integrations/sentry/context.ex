defmodule ErrorStory.Integrations.Sentry.Context do
  @moduledoc """
  Sentry normalization layer.

  Converts Sentry webhook payloads into `%ErrorStory.Incident{}`. Raw HTTP and
  signature details stay in `ErrorStory.Integrations.Sentry.Api`.
  """

  @behaviour ErrorStory.Integrations.ErrorTracker

  alias ErrorStory.Evidence
  alias ErrorStory.Incident
  alias ErrorStory.Integrations.Sentry.Api

  @impl ErrorStory.Integrations.ErrorTracker
  @doc """
  Normalizes a Sentry webhook payload into an incident.

  ## Parameters

    * `payload` - decoded Sentry webhook payload.
    * `opts` - optional metadata. Pass `fetch_details: true` to fetch Sentry
      issue and event details before normalization. Event detail hydration also
      requires `:organization_slug` and `:project_slug`.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` or `{:error, reason}`.
  """
  @spec normalize_webhook(map(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
  def normalize_webhook(payload, opts \\ []) when is_map(payload) do
    payload_result =
      if Keyword.get(opts, :fetch_details, false) do
        fetch_details(payload, opts)
      else
        {:ok, payload}
      end

    with {:ok, sentry_payload} <- payload_result do
      normalize_payload(sentry_payload, opts)
    end
  end

  defp fetch_details(payload, opts) do
    webhook_data = Map.get(payload, "data", %{})
    issue = Map.get(webhook_data, "issue", %{})
    event = Map.get(webhook_data, "event", %{})

    with {:ok, issue} <- fetch_issue_details(issue, opts),
         {:ok, event} <- fetch_event_details(event, opts) do
      webhook_data =
        webhook_data
        |> Map.put("issue", issue)
        |> Map.put("event", event)

      {:ok, Map.put(payload, "data", webhook_data)}
    end
  end

  defp fetch_issue_details(issue, opts) do
    case Map.get(issue, "id") do
      issue_id when is_binary(issue_id) and issue_id != "" ->
        case Api.fetch_issue(issue_id, opts) do
          {:ok, fetched_issue} -> {:ok, Map.merge(issue, fetched_issue)}
          {:error, reason} -> {:error, {:sentry_detail_fetch_failed, :issue, reason}}
        end

      _missing_issue_id ->
        {:ok, issue}
    end
  end

  defp fetch_event_details(event, opts) do
    organization_slug = Keyword.get(opts, :organization_slug)
    project_slug = Keyword.get(opts, :project_slug)
    event_id = Map.get(event, "event_id")

    if fetch_event_details?(organization_slug, project_slug, event_id) do
      case Api.fetch_project_event(organization_slug, project_slug, event_id, opts) do
        {:ok, fetched_event} -> {:ok, Map.merge(event, fetched_event)}
        {:error, reason} -> {:error, {:sentry_detail_fetch_failed, :event, reason}}
      end
    else
      {:ok, event}
    end
  end

  defp fetch_event_details?(organization_slug, project_slug, event_id) do
    is_binary(organization_slug) and organization_slug != "" and is_binary(project_slug) and
      project_slug != "" and is_binary(event_id) and event_id != ""
  end

  defp normalize_payload(payload, opts) do
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
        release: first_present([Map.get(event, "release"), issue_release(issue)]),
        fingerprint: fingerprint(issue, event),
        request_id: request_id(event),
        trace_id: trace_id(event),
        user_id: user_id(event),
        session_id: session_id(event),
        route: route(event),
        error: Map.get(event, "exception", %{}),
        stacktrace: stacktrace(event),
        metadata: %{
          action: Map.get(payload, "action"),
          installation_uuid: Map.get(payload, "installation", %{}) |> Map.get("uuid"),
          event_id: Map.get(event, "event_id"),
          culprit: Map.get(issue, "culprit"),
          transaction: Map.get(event, "transaction"),
          method: event |> Map.get("request", %{}) |> Map.get("method"),
          tags: tags(event)
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
        issue_id: Map.get(issue, "id"),
        event_id: Map.get(event, "event_id"),
        culprit: Map.get(issue, "culprit"),
        transaction: Map.get(event, "transaction"),
        tags: tags(event),
        stacktrace: stacktrace(event),
        action: Map.get(payload, "action")
      },
      links: sentry_links(issue, event)
    )
  end

  defp issue_release(%{"firstRelease" => %{"version" => version}}), do: version
  defp issue_release(%{"firstRelease" => version}) when is_binary(version), do: version
  defp issue_release(_issue), do: nil

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

  defp session_id(event) do
    event
    |> Map.get("contexts", %{})
    |> Map.get("trace", %{})
    |> Map.get("data", %{})
    |> Map.get("session_id")
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

  defp tags(%{"tags" => tags}) when is_list(tags) do
    Map.new(tags, fn
      [key, value] -> {key, value}
      {key, value} -> {key, value}
      other -> {inspect(other), true}
    end)
  end

  defp tags(_event), do: %{}

  defp sentry_links(issue, event) do
    [Map.get(issue, "permalink"), Map.get(event, "web_url")]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&%{source: :sentry, url: &1})
  end

  defp first_present(values) do
    Enum.find(values, fn value -> value not in [nil, ""] end)
  end
end
