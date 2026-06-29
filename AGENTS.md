# ErrorStory Agent Instructions

This is an open source Elixir library, not a Phoenix application. Keep core modules host-app-neutral and dependency-light.

## Iron Laws

If code would violate an Iron Law, stop, cite the law, and propose a compliant alternative.

### HTTP And External Services

- **All outbound HTTP goes through `ErrorStory.Request`**. Provider modules must not call `Req.get/post/put/delete` directly.
- **All external HTTP must be mocked in tests**. Normal tests never hit real external APIs.
- **Webhook signatures must be verified on raw body before side effects**. Use `<Provider>.Api.verify_event_signature/3`-style helpers.
- **Provider `Api` modules own auth and base URLs**. Provider `Context` modules own normalization and meaning.

### Library Boundaries

- **Core must work without Phoenix, Ecto, Oban, or a database**. These belong in optional adapters only.
- **Provider payloads must not leak into agent/video code**. Agent and video modules consume `%ErrorStory.Incident{}` and `%ErrorStory.Evidence{}`.
- **Public APIs must be outside-in**. Every public function needs a concrete caller, behaviour contract, or documented user-facing purpose.

### Security And Privacy

- **Never log secrets**: no API keys, tokens, auth headers, cookies, full request/response bodies, or arbitrary snapshots.
- **Snapshots are allowlist-only**. Do not capture unfiltered params or user-provided maps.
- **Never use `String.to_atom/1` on user/provider input**. Use whitelists or `String.to_existing_atom/1` only where safe.
- **Never interpolate untrusted input into shell commands, SQL, or templates**.

### Elixir And OTP

- **No new process without a runtime reason**. Start synchronous; add GenServer/Task/Supervisor only when concurrency, isolation, or state requires it.
- **Do not rebind inside `if/case/cond` expecting outer bindings to change**. Assign the whole expression result.
- **Pattern match on full response tuples**. Handle `{:ok, _}` and `{:error, _}` explicitly unless crash-on-error is intentional.

### Testing

- **Tests must be meaningful**. Every test verifies a distinct behavior.
- **Never use `Process.sleep/1` or `Process.alive?/1` in tests**. Use monitors, messages, or synchronous APIs.
- **External API tests use stubs/fixtures**. Real-network tests must be opt-in and excluded from default CI.
- **Prefer pattern matching on full responses** over many individual field assertions.

## Design System

ErrorStory's design system is architectural first:

- normalized incidents are the internal contract
- provider-specific knowledge lives at provider leaves
- deterministic video/report generation uses real evidence
- optional host adapters wrap the core without changing it

## Quality Gates

Before completing non-trivial work:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

Also scan changed code for `IO.inspect`, `dbg()`, `IO.puts`, and accidental secret logging.
