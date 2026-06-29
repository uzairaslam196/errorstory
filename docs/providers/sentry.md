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

Raw Sentry issue/event maps stay inside the Sentry error evidence payload. Agent, report, and video modules should consume normalized incident fields and evidence summaries.

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

## Fixture

`priv/fixtures/sentry_issue_webhook.json` is the canonical local demo fixture. It is intentionally small but includes enough issue, event, request, user, trace, stack, and tag data to exercise the Sentry MVP path.
