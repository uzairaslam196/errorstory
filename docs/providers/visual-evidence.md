# Visual Evidence

ErrorStory accepts visual evidence from host apps and observability providers,
but it does not record browser sessions, run browser automation, or capture
screenshots itself in this phase.

Host apps can attach screenshots, replay links, and DOM snapshot references
with `ErrorStory.visual_evidence/3`:

```elixir
{:ok, screenshot} =
  ErrorStory.visual_evidence(:screenshot, %{
    source: :playwright,
    summary: "Checkout form before submit",
    url: "https://cdn.example.com/errorstory/frame.png",
    route: "/checkout",
    viewport: %{width: 1440, height: 900},
    occurred_at: DateTime.utc_now(),
    highlight: %{selector: "#pay", text: "Pay button"}
  })

incident = ErrorStory.Incident.add_evidence(incident, screenshot)
```

Supported visual evidence types:

- `:screenshot` for a captured image URL or local file path.
- `:replay` for a replay URL from a session replay provider.
- `:dom_snapshot` for a DOM snapshot id or safe URL.

Accepted metadata fields are:

- `:source`
- `:summary`
- `:route`
- `:url`
- `:file_path`
- `:replay_url`
- `:dom_snapshot_id`
- `:viewport`
- `:occurred_at`
- `:highlight`

Every visual evidence item must include at least one real reference: `:url`,
`:file_path`, `:replay_url`, `:dom_snapshot_id`, `:route`, or `:occurred_at`.
ErrorStory only stores allowlisted metadata from the helper; arbitrary maps such
as full request params, cookies, storage dumps, or page state should not be
passed as visual evidence.

## Provider Examples

PostHog, LogRocket, OpenReplay, and Highlight can provide replay URLs. Pass the
provider replay link through `:replay_url`:

```elixir
{:ok, replay} =
  ErrorStory.visual_evidence(:replay, %{
    source: :post_hog,
    summary: "Session replay around checkout failure",
    replay_url: "https://app.posthog.com/project/123/replay/456",
    route: "/checkout"
  })
```

Playwright or custom capture jobs can provide screenshots:

```elixir
{:ok, screenshot} =
  ErrorStory.visual_evidence(:screenshot, %{
    source: :playwright,
    file_path: "/var/app/errorstory/req_123.png",
    route: "/checkout",
    viewport: %{width: 1280, height: 720}
  })
```

Custom instrumentation can provide DOM snapshot ids:

```elixir
{:ok, dom_snapshot} =
  ErrorStory.visual_evidence(:dom_snapshot, %{
    source: :custom_capture,
    dom_snapshot_id: "dom_req_123_001",
    route: "/checkout",
    occurred_at: ~U[2026-01-02 03:04:05Z]
  })
```

Scene plans render browser-view scenes only from real visual evidence. When an
incident has logs, stack traces, and journey events but no visual references,
ErrorStory keeps the report text-based and includes a warning instead of
inventing UI.
