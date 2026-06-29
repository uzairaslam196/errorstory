# Phase 03 - Sentry Detail Hydration

## Goal

Make sparse Sentry webhooks more useful without changing ErrorStory's core
boundary. Host apps can opt in to fetching issue and event details, then receive
the same normalized `%ErrorStory.Incident{}` shape used by reports, explanations,
and scene plans.

## Non-Goals

- No database, Phoenix, Oban, or background job dependency.
- No automatic webhook side effects before signature verification.
- No raw Sentry issue or event payload retention in normalized evidence.
- No provider payload branching in agent, report, or video modules.

## Implementation

1. **Opt-in hydration**
   - `ErrorStory.normalize(:sentry, payload, fetch_details: true, ...)`
     fetches Sentry details before normalization.
   - Issue hydration requires a Sentry issue id.
   - Event hydration requires `organization_slug`, `project_slug`, and event id.

2. **Provider boundary**
   - `ErrorStory.Integrations.Sentry.Api` owns Sentry HTTP calls.
   - `ErrorStory.Integrations.Sentry.Context` owns merging fetched fields into
     the provider payload before allowlisted normalization.
   - Downstream modules continue to consume only `%ErrorStory.Incident{}` and
     `%ErrorStory.Evidence{}`.

3. **Failure behavior**
   - Detail fetch failures return structured errors such as
     `{:sentry_detail_fetch_failed, :issue, reason}`.
   - Missing event coordinates skip event fetching instead of failing.

## Tests

- Hydrates sparse webhook payloads with mocked Sentry issue and event details.
- Skips event detail fetch without project coordinates.
- Returns structured errors for issue and event fetch failures.
- Keeps raw Sentry issue and event maps out of normalized evidence.

## Gates

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

Additional scans:

- direct `Req.*` usage remains confined to `ErrorStory.Request`
- no debug artifacts
- no raw Sentry issue/event retention in normalized evidence docs or tests
