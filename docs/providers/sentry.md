# Sentry Provider

ErrorStory's Sentry provider turns issue and event webhook data into a normalized `%ErrorStory.Incident{}`.

## Normalized Fields

The Sentry context currently extracts:

- issue id
- event id
- issue title or event message
- environment
- release
- culprit
- transaction
- request URL or route
- user id
- request id
- trace id
- fingerprint
- stack frames
- tags
- Sentry permalinks

Normalized Sentry evidence keeps allowlisted fields such as issue id, event id,
culprit, transaction, tags, stack frames, and links. Raw Sentry issue and event
maps are not retained in normalized evidence. Agent, report, and video modules
should consume normalized incident fields and evidence summaries.

## Webhook Safety

Verify the webhook signature on the raw body before decoding or normalizing:

```elixir
:ok =
  ErrorStory.Integrations.Sentry.Api.verify_event_signature(
    raw_body,
    sentry_signature,
    sentry_webhook_secret
  )
```

## Detail Hydration

Sentry webhooks may include only issue and event identifiers. ErrorStory can
hydrate those sparse payloads through Sentry's API when a host app opts in:

```elixir
{:ok, incident} =
  ErrorStory.normalize(:sentry, payload,
    fetch_details: true,
    auth_token: sentry_auth_token,
    organization_slug: "acme",
    project_slug: "billing"
  )
```

Issue hydration runs when the webhook has an issue id. Event hydration also
requires `organization_slug`, `project_slug`, and event id. If event coordinates
are missing, ErrorStory normalizes the available issue data and skips the event
fetch.

Detail fetch failures return structured errors:

```elixir
{:error, {:sentry_detail_fetch_failed, :issue, reason}}
{:error, {:sentry_detail_fetch_failed, :event, reason}}
```

This fetch happens only after the host app has verified the webhook signature.
The fetched Sentry maps are used as provider input, then normalized into
allowlisted incident and evidence fields.

## Fixture

`priv/fixtures/sentry_issue_webhook.json` is the canonical local demo fixture. It is intentionally small but includes enough issue, event, request, user, trace, stack, and tag data to exercise the Sentry MVP path.
