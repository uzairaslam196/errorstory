# ErrorStory

ErrorStory is an open source Elixir library for turning production errors into grounded incident explanations and lightweight video/report artifacts.

It is designed for any Elixir or Phoenix project to add as a dependency, configure with provider credentials, normalize evidence from tools like Sentry, Loki, PostHog, and OpenAI, then generate useful developer/product/support summaries and evidence-based scene plans.

ErrorStory is **not** a replacement for observability tools. It is the understanding layer on top of them.

## Status

Early library scaffold. The core contracts, provider boundaries, and first deterministic report renderer are in place. APIs may still change before the first stable Hex release.

## Why

Production debugging usually requires opening several tools, copying context into an AI assistant, and manually reconstructing the user journey.

ErrorStory keeps that flow grounded:

```text
Sentry / Loki / PostHog / app snapshots
  -> provider Api + Context modules
  -> %ErrorStory.Incident{} + %ErrorStory.Evidence{}
  -> explanation + video scene plan
  -> deterministic HTML report now, MP4/WebM renderers later
```

The important rule: agents and renderers consume normalized evidence. They do not care whether an event came from Sentry, PostHog, Loki, or a custom provider.

## Installation

When published to Hex:

```elixir
def deps do
  [
    {:error_story, "~> 0.1.0"}
  ]
end
```

From this repository during development:

```elixir
def deps do
  [
    {:error_story, path: "../errorstory"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

ErrorStory accepts literal values or `{:system, "ENV_VAR"}` tuples for secrets.

```elixir
config :error_story,
  sentry_auth_token: {:system, "SENTRY_AUTH_TOKEN"},
  loki_base_url: {:system, "LOKI_BASE_URL"},
  post_hog_base_url: "https://app.posthog.com",
  post_hog_project_id: {:system, "POST_HOG_PROJECT_ID"},
  post_hog_api_key: {:system, "POST_HOG_API_KEY"},
  openai_api_key: {:system, "OPENAI_API_KEY"}
```

Provider functions also accept per-call options, which is usually better for tests, multi-tenant apps, or customer-specific credentials.

## Quick Start

Capture an application error as a normalized incident:

```elixir
{:ok, incident} =
  ErrorStory.capture(%RuntimeError{message: "checkout failed"},
    service: "billing",
    environment: "prod",
    release: "v1.4.2",
    request_id: "req_123",
    trace_id: "trace_456"
  )
```

Add safe application state with an allowlist:

```elixir
{:ok, snapshot} =
  ErrorStory.snapshot(
    :billing_checkout,
    %{
      account_id: "acct_123",
      billing_account_id: nil,
      plan: "yearly",
      token: "secret"
    },
    allow: [:account_id, :billing_account_id, :plan]
  )

# snapshot.attrs does not include :token
```

Attach visual evidence from a host app or external provider:

```elixir
{:ok, screenshot} =
  ErrorStory.visual_evidence(:screenshot, %{
    source: :playwright,
    summary: "Checkout form before submit",
    url: "https://cdn.example.com/errorstory/frame.png",
    route: "/checkout",
    viewport: %{width: 1440, height: 900}
  })

incident = ErrorStory.Incident.add_evidence(incident, screenshot)
```

Build a deterministic explanation:

```elixir
{:ok, explanation} = ErrorStory.explain(incident)

explanation.developer_summary
explanation.next_checks
```

Create and render a video/report artifact:

```elixir
{:ok, scene_plan} = ErrorStory.video_plan(incident)
{:ok, %{format: :html_report, content: html}} = ErrorStory.render_video(scene_plan)
```

The v1 renderer returns an HTML report. Future MP4/WebM renderers should use the same scene-plan contract.

Or use the end-to-end report pipeline:

```elixir
{:ok, report} =
  ErrorStory.report(incident,
    logs: {ErrorStory.Integrations.Loki.Context, [base_url: "https://loki.example.com"]},
    journey:
      {ErrorStory.Integrations.PostHog.Context,
       [project_id: "12345", api_key: System.fetch_env!("POST_HOG_API_KEY")]}
  )

report.artifact.format
report.artifact.content
```

If one enrichment provider fails, `ErrorStory.report/2` returns a structured error with the provider failures and a partial report built from the evidence that was available.

## Demo

Generate a local report from the bundled Sentry fixture:

```bash
mix error_story.demo
```

The command writes:

```text
tmp/error_story_demo_report.html
```

The output file is ignored by Git.

## Provider Examples

### Sentry Webhook Normalization

```elixir
with :ok <-
       ErrorStory.Integrations.Sentry.Api.verify_event_signature(
         raw_body,
         sentry_signature,
         sentry_webhook_secret
       ),
     {:ok, payload} <- Jason.decode(raw_body),
     {:ok, incident} <- ErrorStory.normalize(:sentry, payload) do
  {:ok, incident}
end
```

Webhook signature verification should happen on the raw body before any side effect.

### Loki Log Enrichment

```elixir
{:ok, incident_with_logs} =
  ErrorStory.enrich(incident,
    logs:
      {ErrorStory.Integrations.Loki.Context,
       [
         base_url: "https://loki.example.com",
         limit: 100
       ]}
  )
```

Loki enrichment searches by `request_id` first, then `trace_id`.

### PostHog Journey Enrichment

```elixir
{:ok, incident_with_journey} =
  ErrorStory.enrich(incident,
    journey:
      {ErrorStory.Integrations.PostHog.Context,
       [
         base_url: "https://app.posthog.com",
         project_id: "12345",
         api_key: System.fetch_env!("POST_HOG_API_KEY")
       ]}
  )
```

PostHog enrichment uses `user_id` or `session_id` from the normalized incident.

### Visual Evidence From Host Apps

ErrorStory accepts screenshots, replay links, and DOM snapshot references with
`ErrorStory.visual_evidence/3`. A host app can pass replay URLs from PostHog,
LogRocket, OpenReplay, or Highlight; screenshot paths or URLs from Playwright or
custom capture; and DOM snapshot ids from custom instrumentation.

ErrorStory does not record browser sessions, capture screenshots, or run browser
automation in this phase. It normalizes safe visual references and renders
browser-view scenes only when those references exist.

See `docs/providers/visual-evidence.md` for examples.

### OpenAI Explanation Provider

```elixir
{:ok, explanation} =
  ErrorStory.explain(incident,
    llm:
      {ErrorStory.Integrations.OpenAI.Context,
       [
         api_key: System.fetch_env!("OPENAI_API_KEY"),
         model: "gpt-4o-mini"
       ]}
  )
```

The LLM receives normalized incident data and evidence summaries, not raw provider payloads.

## Core Concepts

### Incident

`%ErrorStory.Incident{}` is the normalized unit of work. It contains stable fields such as:

- `title`
- `source`
- `service`
- `environment`
- `release`
- `request_id`
- `trace_id`
- `user_id`
- `session_id`
- `route`
- `evidence`
- `links`

Provider-specific fields belong in evidence payloads, not in agent or renderer code.

### Evidence

`%ErrorStory.Evidence{}` represents one grounded fact:

- `:error`
- `:log`
- `:journey_event`
- `:screenshot`
- `:replay`
- `:dom_snapshot`
- `:release`
- `:code_hint`
- `:metadata`

Visual scenes are only generated from visual evidence: screenshots, replay frames, or DOM snapshots with visual metadata.

### Scene Plan

`%ErrorStory.Video.ScenePlan{}` is a structured plan for a future video or report:

- summary scene
- evidence timeline
- optional browser scenes from real visual evidence
- technical context scene
- warnings when visual evidence is missing

The renderer must not invent product UI. If there is no screenshot, replay, or DOM evidence, ErrorStory renders timeline/text scenes instead.

## Provider Architecture

Each provider follows the same split:

```text
lib/error_story/integrations/<provider>/api.ex
lib/error_story/integrations/<provider>/context.ex
```

`Api` modules own:

- base URLs
- auth headers
- raw HTTP requests
- webhook signature verification
- provider endpoint shapes

`Context` modules own:

- request shaping
- response parsing
- normalization into `%ErrorStory.Incident{}` or `%ErrorStory.Evidence{}`
- provider-specific business meaning

Shared behavior modules define provider contracts:

- `ErrorStory.Integrations.ErrorTracker`
- `ErrorStory.Integrations.LogProvider`
- `ErrorStory.Integrations.JourneyProvider`
- `ErrorStory.Integrations.LLMProvider`

## Privacy And Security

ErrorStory is designed to be safe by default, but host applications control what they pass in.

- Use `ErrorStory.snapshot/3` with explicit `allow:` keys.
- Do not pass tokens, API keys, cookies, payment data, passwords, or arbitrary request params.
- Do not log full provider payloads or full snapshots.
- Verify webhook signatures before normalization or persistence.
- Keep customer credentials outside source code.

## What ErrorStory Is Not

ErrorStory does not try to be:

- a log store
- a Sentry replacement
- a PostHog replacement
- a full session replay engine
- a job queue
- a database-backed incident product
- a Phoenix application

Those can be optional host-app integrations later. The core library stays small and host-neutral.

## Development

```bash
mix deps.get
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

Normal tests must not hit real external APIs. Provider HTTP is tested through `Req.Test`.

## Current Test Coverage

The current test suite covers:

- exception capture
- safe snapshot allowlisting
- normalized incident/evidence construction
- Sentry webhook normalization
- Sentry signature verification
- Loki mocked log enrichment
- PostHog mocked journey enrichment
- OpenAI mocked explanation generation
- deterministic local explanations
- video scene-plan behavior with and without visual evidence
- HTML report rendering and escaping
- end-to-end report orchestration
- local demo task generation

## Roadmap

- Add richer Sentry issue/event fetching.
- Add Grafana alert webhook normalization.
- Add visual evidence ingestion from replay/screenshot providers.
- Add a browser-capture adapter for host apps that can safely render exact pages.
- Add MP4/WebM rendering from scene plans.
- Add optional Plug/Phoenix helpers without making Phoenix a core dependency.

## License

MIT. See `LICENSE`.
